# Shared by the tests: a copy of the repo in a temporary folder, played without opening a new PowerShell. Each command
# runs in a runspace of its own, at its global scope as a quest's session runs it, then the same check the session's
# prompt runs; so the tests play the game as a player would.
#
# Harness state lives in $global:TQ, so it reads the same under Pester and anywhere else.

function Initialize-Quest {
  $repo = Split-Path $PSScriptRoot -Parent
  $questHome = Join-Path ([System.IO.Path]::GetTempPath()) ('tq-' + [guid]::NewGuid().ToString('N').Substring(0, 10))
  New-Item -ItemType Directory -Path $questHome | Out-Null
  Copy-Item -LiteralPath (Join-Path $repo 'quest.ps1') -Destination $questHome
  Copy-Item -LiteralPath (Join-Path $repo '.quest') -Destination $questHome -Recurse -Force
  Remove-Item -LiteralPath (Join-Path $questHome '.quest/state') -Recurse -Force -ErrorAction SilentlyContinue
  $global:TQ = @{
    Home = $questHome
    Log = [System.Text.StringBuilder]::new()
    Env = @{}
    Shell = $null
    CanLink = $false
  }
  foreach ($k in 'PATH', 'POWER', 'QUEST_HOME', 'QUEST_ADVENTURE', 'QUEST_SHELL', 'QUEST_NO_SHELL') { $TQ.Env[$k] = [Environment]::GetEnvironmentVariable($k) }
  $env:QUEST_HOME = $questHome
  Remove-Item Env:QUEST_ADVENTURE, Env:QUEST_SHELL, Env:QUEST_NO_SHELL, Env:POWER -ErrorAction SilentlyContinue
  try {
    $probe = Join-Path $questHome 'link-probe'
    New-Item -ItemType SymbolicLink -Path $probe -Value (Join-Path $questHome 'quest.ps1') -ErrorAction Stop | Out-Null
    Remove-Item -LiteralPath $probe -Force
    $TQ.CanLink = $true
  } catch { $TQ.CanLink = $false }
}

function Clear-Quest {
  if (-not $global:TQ) { return }
  if ($env:QUEST_ADVENTURE) { Invoke-QuestCli '__leave' | Out-Null }
  if ($TQ.Shell) { $TQ.Shell.Runspace.Close(); $TQ.Shell.Dispose() }
  foreach ($k in $TQ.Env.Keys) { [Environment]::SetEnvironmentVariable($k, $TQ.Env[$k]) }
  Remove-Item -LiteralPath $TQ.Home -Recurse -Force -ErrorAction SilentlyContinue
}

# The quest command, as a player types it: its output, and $LASTEXITCODE.
function Invoke-QuestCli {
  $out = & (Get-Process -Id $PID).Path -NoProfile -NonInteractive -File (Join-Path $TQ.Home 'quest.ps1') @args 2>&1 | Out-String
  [void]$TQ.Log.AppendLine("> quest $($args -join ' ')").AppendLine($out)
  return $out
}

# A fresh copy of an adventure, and a runspace inside it as a quest's session would be.
function Start-QuestPlay([string]$Adventure) {
  $env:QUEST_NO_SHELL = '1'
  Invoke-QuestCli start $Adventure | Out-Null
  Remove-Item Env:QUEST_NO_SHELL
  $env:QUEST_ADVENTURE = $Adventure
  $env:QUEST_SHELL = 'powershell'
  $rs = [runspacefactory]::CreateRunspace()
  $rs.Open()
  $ps = [powershell]::Create()
  $ps.Runspace = $rs
  $TQ.Shell = $ps
  $where = Get-Content -LiteralPath (Join-Path $TQ.Home ".quest/state/$Adventure/lastcwd") | Select-Object -First 1
  # A test never changes the computer's execution policy: Set-ExecutionPolicy here only notes that it was typed.
  $setup = @'
param($QuestHome, $Where)
Import-Module (Join-Path $QuestHome '.quest/lib/Quest.psm1')
(Get-PSProvider FileSystem).Home = $QuestHome
Set-Variable -Name HOME -Value $QuestHome -Scope Global -Force
function global:Set-ExecutionPolicy { param([Parameter(ValueFromRemainingArguments)]$Rest) }
Set-Location -LiteralPath $Where
'@
  [void]$ps.AddScript($setup).AddArgument($TQ.Home).AddArgument($where)
  [void]$ps.Invoke()
  $ps.Commands.Clear()
}

function Write-QuestStreams {
  foreach ($r in $TQ.Shell.Streams.Information) { [void]$TQ.Log.AppendLine("$($r.MessageData)") }
  foreach ($r in $TQ.Shell.Streams.Error) { [void]$TQ.Log.AppendLine("ERROR: $r") }
  $TQ.Shell.Streams.ClearStreams()
}

# A command typed in: runs it, then the prompt's check, as pressing Enter in a quest does.
function Send-QuestLine([string]$Line) {
  $ps = $TQ.Shell
  [void]$TQ.Log.AppendLine("PS> $Line")
  $ps.Commands.Clear()
  [void]$ps.AddScript($Line)
  $ok = $true
  try {
    $out = $ps.Invoke()
    foreach ($o in $out) { [void]$TQ.Log.AppendLine("$o") }
    $ok = -not $ps.HadErrors
  } catch {
    $ok = $false
    [void]$TQ.Log.AppendLine("ERROR: $($_.Exception.Message)")
  }
  Write-QuestStreams
  $ps.Commands.Clear()
  [void]$ps.AddCommand('Invoke-QuestAfter').AddParameter('Succeeded', $ok).AddParameter('Line', $Line)
  [void]$ps.Invoke()
  Write-QuestStreams
  $ps.Commands.Clear()
}

# A walkthrough's line as this computer can type it: no symbolic links without the right (Windows Developer Mode or
# admin) means a copy, which the story accepts the same; PATH's separator is : off Windows.
function ConvertTo-LocalLine([string]$Line) {
  if (-not $TQ.CanLink) { $Line = $Line -replace '^New-Item -ItemType SymbolicLink -Path (\S+) -Value (\S+)$', 'Copy-Item $2 $1' }
  if (-not $IsWindows -and $Line -like '$env:PATH +=*') { $Line = $Line.Replace('";', '":').Replace('\', '/') }
  return $Line
}

function Invoke-Walkthrough([string]$Adventure) {
  Start-QuestPlay $Adventure
  . (Join-Path $TQ.Home ".quest/stories/$Adventure/walkthrough.ps1")
  foreach ($line in $QS_WALKTHROUGH) { Send-QuestLine (ConvertTo-LocalLine $line) }
}

function Get-QuestState([string]$Name) {
  $f = Join-Path $TQ.Home ".quest/state/$env:QUEST_ADVENTURE/$Name"
  if (Test-Path -LiteralPath $f) { return @(Get-Content -LiteralPath $f) }
  return @()
}

function Get-QuestLog { $TQ.Log.ToString() }

function Get-StoryList([string]$Adventure, [string]$Field) {
  $line = Select-String -LiteralPath (Join-Path $TQ.Home ".quest/stories/$Adventure/story.ps1") -Pattern "^\s*$Field = (.*)$" | Select-Object -First 1
  return Invoke-Expression $line.Matches.Groups[1].Value
}

# Everything found and the quest complete; the log of the play when not.
function Assert-QuestComplete([string]$Adventure) {
  foreach ($t in (Get-StoryList $Adventure 'Treasures')) {
    if ((Get-QuestState 'found') -notcontains $t) { throw "Treasure not found: $t`n$(Get-QuestLog)" }
  }
  if ((Get-StoryList $Adventure 'Coin') -and -not (Test-Path -LiteralPath (Join-Path $TQ.Home ".quest/state/$Adventure/coin"))) { throw "The coin was not found`n$(Get-QuestLog)" }
  if (-not (Test-Path -LiteralPath (Join-Path $TQ.Home ".quest/state/$Adventure/finished"))) { throw "The quest did not finish`n$(Get-QuestLog)" }
}
