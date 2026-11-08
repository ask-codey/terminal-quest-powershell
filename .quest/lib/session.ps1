# A quest's PowerShell: started by ./quest.ps1 start, with your home folder as the repo, a prompt that shows where you
# are, and a check of the story after every command. Type exit to leave; ./quest.ps1 start puts you back where you were.
Import-Module (Join-Path $env:QUEST_HOME '.quest/lib/Quest.psm1')
(Get-PSProvider FileSystem).Home = $env:QUEST_HOME
Set-Variable -Name HOME -Value $env:QUEST_HOME -Scope Global -Force

function global:quest { & (Join-Path $env:QUEST_HOME 'quest.ps1') @args }

# This quest's commands from before, so Get-History (and the logbook) remember them.
$global:__questHistory = Join-Path $env:QUEST_HOME ".quest/state/$env:QUEST_ADVENTURE/history.csv"
if (Test-Path -LiteralPath $global:__questHistory) { Import-Csv -LiteralPath $global:__questHistory | Add-History -ErrorAction SilentlyContinue }
$global:__questSeen = (Get-History -Count 1).Id

function global:prompt {
  $ok = $?
  $code = $global:LASTEXITCODE
  $h = Get-History -Count 1
  if ($h -and $h.Id -ne $global:__questSeen) {
    $global:__questSeen = $h.Id
    $h | Select-Object CommandLine, ExecutionStatus, StartExecutionTime, EndExecutionTime | Export-Csv -LiteralPath $global:__questHistory -Append -NoTypeInformation
    try { Invoke-QuestAfter -Succeeded $ok -Line $h.CommandLine } catch { Write-Host "(Terminal Quest couldn't check that command: $_)" }
  }
  $global:LASTEXITCODE = $code
  $here = (Get-Location).Path
  if ($here.StartsWith($env:QUEST_HOME, [System.StringComparison]::OrdinalIgnoreCase)) { $here = '~' + $here.Substring($env:QUEST_HOME.Length) }
  $e = [char]27
  "$e[1;32mplayer@quest$e[0m:$e[1;34m$here$e[0m> "
}

$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { & (Join-Path $env:QUEST_HOME 'quest.ps1') __leave }
$where = Get-Content -LiteralPath (Join-Path $env:QUEST_HOME ".quest/state/$env:QUEST_ADVENTURE/lastcwd") -ErrorAction SilentlyContinue | Select-Object -First 1
if ($where -and (Test-Path -LiteralPath $where)) { Set-Location -LiteralPath $where } else { Set-Location -LiteralPath (Join-Path $env:QUEST_HOME $env:QUEST_ADVENTURE) }
