# Terminal Quest for PowerShell: the engine. quest.ps1, the prompt after every command, and every story object use it.
#
# A story (.quest/stories/<adventure>/story.ps1) is built from the same story the online game plays: its checks and
# effects call the q_ functions below. The world is checked as it is (real folders, files, variables, functions and
# programs). What a command READ can't be seen afterwards, so the typed line is read instead, with PowerShell's own
# parser: Get-Content (gc, cat, type), Import-Csv, Select-String (only files it found a match in), dot-sourcing, and
# Get-Content on what a Get-ChildItem earlier in the pipeline found.
#
# Copyright (c) 2026 FullStack Devs. See LICENSE.
Set-StrictMode -Off
$ErrorActionPreference = 'Continue'

$script:Esc = [char]27
$script:Color = -not [Console]::IsOutputRedirected

# ------------------------------------------------------------------------------------------------ where things are

function q_load([string]$name) {
  $script:QS_NAME = $name
  $script:QS_DIR = Join-Path $env:QUEST_HOME ".quest/stories/$name"
  $script:QS_ROOT = Join-Path $env:QUEST_HOME $name
  $script:QS_STATE = Join-Path $env:QUEST_HOME ".quest/state/$name"
  $story = Join-Path $script:QS_DIR 'story.ps1'
  if (-not (Test-Path -LiteralPath $story)) {
    Write-Host "There is no adventure called `"$name`". Try: ./quest.ps1 list"
    return $false
  }
  . $story
  return $true
}

function q_full([string]$path) {
  [System.IO.Path]::GetFullPath($path).TrimEnd([char]'\', [char]'/')
}

# The path inside the adventure, lower case with /, '' for its own folder; $null outside it.
function q_key([string]$path) {
  if (-not $path) { return $null }
  $root = q_full $script:QS_ROOT
  $full = q_full $path
  if ($full -ieq $root) { return '' }
  $prefix = $root + [System.IO.Path]::DirectorySeparatorChar
  if ($full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $full.Substring($prefix.Length).Replace('\', '/').ToLowerInvariant()
  }
  return $null
}

function q_path([string]$rel) { Join-Path $script:QS_ROOT $rel }

# ------------------------------------------------------------------------------------------------ remembering

function q_file([string]$name) { Join-Path $script:QS_STATE $name }

function q_lines([string]$name) {
  $f = q_file $name
  if (Test-Path -LiteralPath $f) { return @(Get-Content -LiteralPath $f) }
  return @()
}

function q_has([string]$name, [string]$value) { return [bool]((q_lines $name) -contains $value) }

function q_add([string]$name, [string]$value) {
  if (q_has $name $value) { return }
  New-Item -ItemType Directory -Force -Path $script:QS_STATE | Out-Null
  Add-Content -LiteralPath (q_file $name) -Value $value
}

function q_del([string]$name, [string]$value) {
  $f = q_file $name
  if (-not (Test-Path -LiteralPath $f)) { return }
  $keep = @((q_lines $name) | Where-Object { $_ -ne $value })
  if ($keep.Count) { Set-Content -LiteralPath $f -Value $keep } else { Remove-Item -LiteralPath $f -Force }
}

function q_mark([string]$name) { New-Item -ItemType Directory -Force -Path $script:QS_STATE | Out-Null; Set-Content -LiteralPath (q_file $name) -Value '' }
function q_marked([string]$name) { return [bool](Test-Path -LiteralPath (q_file $name)) }

# ------------------------------------------------------------------------------------------------ saying things

function q_paint([string]$code, [string]$text) {
  if ($script:Color) { return "$script:Esc[${code}m$text$script:Esc[0m" }
  return $text
}

function q_say([string]$text) {
  foreach ($line in ($text -split "`n")) { Write-Host (q_paint '33' $line) }
}

function q_gold([string]$text) { Write-Host (q_paint '1;33' $text) }
function q_dim([string]$text) { Write-Host (q_paint '2' $text) }

# One row of game-history.csv at the repo's root. A reset never clears it.
function q_history([string]$event, [string]$detail) {
  $file = Join-Path $env:QUEST_HOME 'game-history.csv'
  if (-not (Test-Path -LiteralPath $file)) { Set-Content -LiteralPath $file -Value 'when,adventure,shell,run,event,detail' }
  $run = (q_lines 'run' | Select-Object -First 1)
  if (-not $run) { $run = '1' }
  $when = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
  Add-Content -LiteralPath $file -Value ('{0},{1},powershell,{2},{3},"{4}"' -f $when, $script:QS_NAME, $run, $event, $detail.Replace('"', '""'))
}

# ------------------------------------------------------------------------------------------------ checks

function q_here { return q_key (Get-Location -PSProvider FileSystem).ProviderPath }
function q_cwd([string]$key) { $h = q_here; return ($null -ne $h -and $h -eq $key) }
function q_visited([string]$key) { return q_has 'visits' $key }
function q_read([string]$key) { return q_has 'reads' $key }
function q_ran([string]$key) { return q_has 'ran' $key }
function q_flag([string]$name) { return q_has 'flags' $name }
function q_treasure([string]$id) { return q_has 'found' $id }
function q_goal([string]$id) { return q_has 'goals' $id }

function q_exists([string]$rel) { return [bool](Test-Path -LiteralPath (q_path $rel)) }

# Reading follows a link; case doesn't matter.
function q_contains([string]$rel, [string]$text) {
  $p = q_path $rel
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return $false }
  $content = Get-Content -LiteralPath $p -Raw -ErrorAction SilentlyContinue
  return [bool]($content -and $content.IndexOf($text, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}

# A script may run when nothing marks it as downloaded from the internet (Windows; elsewhere there is no such mark).
function q_executable([string]$rel) {
  $p = q_path $rel
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return $false }
  if (-not $IsWindows) { return $true }
  return -not (Get-Item -LiteralPath $p -Stream Zone.Identifier -ErrorAction SilentlyContinue)
}

function q_env([string]$name, [string]$how, [string]$value) {
  $v = [Environment]::GetEnvironmentVariable($name)
  if ($null -eq $v) { return $false }
  switch ($how) {
    'equals' { return $v -ceq $value }
    'includes' { return $v.IndexOf($value, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 }
    default { return $true }
  }
}

# A variable in the player's session (not an environment variable).
function q_variable([string]$name, [string]$value) {
  $v = Get-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue
  if (-not $v) { return $false }
  return ($value -eq '' -or "$($v.Value)" -eq $value)
}

function q_alias([string]$name) { return [bool](Get-Alias -Name $name -ErrorAction SilentlyContinue) }
function q_function([string]$name) { return [bool](Get-Command -Name $name -CommandType Function -ErrorAction SilentlyContinue) }

function q_used {
  foreach ($n in $args) { if (q_has 'used' "$n".ToLowerInvariant()) { return $true } }
  return $false
}

# How many visible names a wildcard matches inside the adventure (hidden ones don't count, as in Get-ChildItem).
function q_count([string]$pattern, [int]$n) {
  $found = @(Get-ChildItem -Path (q_path $pattern) -ErrorAction SilentlyContinue | Where-Object { -not $_.Name.StartsWith('.') })
  return $found.Count -eq $n
}

function q_pid([string]$name) {
  $p = q_lines "pids/$name" | Select-Object -First 1
  if ($p) { return [int]$p }
  return $null
}

function q_running([string]$name) {
  $id = q_pid $name
  if (-not $id) { return $false }
  return [bool](Get-Process -Id $id -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq $name })
}

function q_stdin_has([string]$text) { return [bool]($script:QS_STDIN -and $script:QS_STDIN.Contains($text)) }

# ------------------------------------------------------------------------------------------------ the story's memory

function q_trigger_ready([int]$i, [bool]$always) { if ($always) { return $true }; return -not (q_has 'triggers' "$i") }
function q_trigger_mark([int]$i) { q_add 'triggers' "$i" }
function q_rule_ready([int]$i) { return -not (q_has 'rules' "$i") }
function q_rule_mark([int]$i) { q_add 'rules' "$i" }
function q_ran_mark([string]$key) { q_add 'ran' $key }

# ------------------------------------------------------------------------------------------------ effects

function q_flag_set([string]$name) { q_add 'flags' $name }
function q_flag_clear([string]$name) { q_del 'flags' $name }
function q_mkdir([string]$rel) { New-Item -ItemType Directory -Force -Path (q_path $rel) | Out-Null }

function q_write([string]$rel, [string]$text) {
  $p = q_path $rel
  New-Item -ItemType Directory -Force -Path (Split-Path $p) | Out-Null
  [System.IO.File]::WriteAllText($p, $text)
  q_hide_dots $script:QS_ROOT
}

function q_link([string]$target, [string]$rel) {
  $p = q_path $rel
  New-Item -ItemType Directory -Force -Path (Split-Path $p) | Out-Null
  New-Item -ItemType SymbolicLink -Path $p -Value $target -ErrorAction SilentlyContinue | Out-Null
}

function q_remove([string]$rel) { Remove-Item -LiteralPath (q_path $rel) -Recurse -Force -ErrorAction SilentlyContinue }

function q_move([string]$from, [string]$to) {
  $src = q_path $from
  if (-not (Test-Path -LiteralPath $src)) { return }
  $dest = q_path $to
  New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
  Move-Item -LiteralPath $src -Destination $dest -Force
}

function q_teleport([string]$rel) { Set-Location -LiteralPath (q_path $rel) }

# Windows marks a file downloaded from the internet; under RemoteSigned it won't run until Unblock-File.
function q_block([string]$rel) {
  if (-not $IsWindows) { return }
  Set-Content -LiteralPath (q_path $rel) -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3"
}

# Git can't store Windows' Hidden attribute, so names starting with a dot get it here (elsewhere they're hidden anyway).
function q_hide_dots([string]$folder) {
  if (-not $IsWindows) { return }
  Get-ChildItem -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name.StartsWith('.') } | ForEach-Object {
    $_.Attributes = $_.Attributes -bor [System.IO.FileAttributes]::Hidden
  }
}

# q_spawn <name> <command>: a program the story starts. Get-Process lists it by its name and Stop-Process stops it.
function q_spawn([string]$name, [string]$command) {
  q_add 'processes' $name
  q_start_process $name
}

function q_start_process([string]$name) {
  if (q_running $name) { return }
  $bin = Join-Path $script:QS_STATE 'bin'
  New-Item -ItemType Directory -Force -Path $bin, (Join-Path $script:QS_STATE 'pids') | Out-Null
  if ($IsWindows) {
    # A copy of Windows' own waitfor.exe, renamed: it only waits (up to a day), and nothing else.
    $exe = Join-Path $bin "$name.exe"
    if (-not (Test-Path -LiteralPath $exe)) { Copy-Item -LiteralPath (Join-Path $env:SystemRoot 'System32\waitfor.exe') -Destination $exe }
    $p = Start-Process -FilePath $exe -ArgumentList '/t', '86400', "terminalquest$(Get-Random)" -WindowStyle Hidden -PassThru
  } else {
    # A copy of sleep, renamed: it only waits (up to a day), and nothing else.
    $exe = Join-Path $bin $name
    if (-not (Test-Path -LiteralPath $exe)) {
      Copy-Item -LiteralPath (Get-Command sleep -CommandType Application | Select-Object -First 1).Source -Destination $exe
      & chmod +x $exe
    }
    $p = Start-Process -FilePath $exe -ArgumentList '86400' -PassThru -RedirectStandardOutput ([System.IO.Path]::GetTempFileName())
  }
  Set-Content -LiteralPath (q_file "pids/$name") -Value $p.Id
}

# The story's programs that should be running and aren't (the player stopped them) are forgotten.
function q_forget_stopped {
  foreach ($name in (q_lines 'processes')) {
    if ($name -and -not (q_running $name)) {
      q_del 'processes' $name
      Remove-Item -LiteralPath (q_file "pids/$name") -Force -ErrorAction SilentlyContinue
    }
  }
}

# Leaving a quest pauses its programs; starting it again starts them again.
function q_pause_processes {
  $dir = Join-Path $script:QS_STATE 'pids'
  if (-not (Test-Path -LiteralPath $dir)) { return }
  foreach ($f in Get-ChildItem -LiteralPath $dir) {
    $id = Get-Content -LiteralPath $f.FullName | Select-Object -First 1
    if ($id) { Stop-Process -Id ([int]$id) -Force -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $f.FullName -Force
  }
}

function q_resume_processes { foreach ($name in (q_lines 'processes')) { if ($name) { q_start_process $name } } }

# ------------------------------------------------------------------------------------------------ goals

function q_current_goal {
  foreach ($g in $script:QS.Goals) { if (-not (q_goal $g)) { return $g } }
  return $null
}

# ------------------------------------------------------------------------------------------------ what a line did

$script:Readers = @('get-content', 'gc', 'cat', 'type', 'import-csv', 'ipcsv')
$script:Searchers = @('select-string', 'sls')
$script:Movers = @('set-location', 'cd', 'sl', 'chdir', 'push-location', 'pushd')
$script:Listers = @('get-childitem', 'gci', 'ls', 'dir')

function q_canonical([System.Management.Automation.Language.CommandAst]$c) {
  $name = $c.GetCommandName()
  if (-not $name) { return $null }
  $alias = Get-Alias -Name $name -ErrorAction SilentlyContinue
  if ($alias) { return $alias.ResolvedCommandName.ToLowerInvariant() }
  return $name.ToLowerInvariant()
}

# A value the line spells out, with no command in it to run: text, numbers, $HOME-style variables, lists of them.
function q_static($ast) {
  if ($null -eq $ast) { return @() }
  if ($ast -is [System.Management.Automation.Language.StringConstantExpressionAst]) { return , $ast.Value }
  if ($ast -is [System.Management.Automation.Language.ConstantExpressionAst]) { return , "$($ast.Value)" }
  if ($ast -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
    if (@($ast.NestedExpressions | Where-Object { $_ -isnot [System.Management.Automation.Language.VariableExpressionAst] }).Count) { return @() }
    return , $ExecutionContext.InvokeCommand.ExpandString($ast.Value)
  }
  if ($ast -is [System.Management.Automation.Language.ArrayLiteralAst]) { return @($ast.Elements | ForEach-Object { q_static $_ }) }
  return @()
}

# Whether a command's arguments are all spelled out, so running it again only does what was typed.
function q_plain([System.Management.Automation.Language.CommandAst]$c) {
  $dynamic = $c.FindAll({
      param($a)
      $a -is [System.Management.Automation.Language.SubExpressionAst] -or
      $a -is [System.Management.Automation.Language.ScriptBlockExpressionAst] -or
      $a -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -or
      ($a -is [System.Management.Automation.Language.VariableExpressionAst] -and $a.VariablePath.UserPath -notin @('HOME', 'true', 'false', 'null'))
    }, $true)
  return @($dynamic).Count -eq 0
}

function q_bound([System.Management.Automation.Language.CommandAst]$c, [string[]]$names) {
  try { $b = [System.Management.Automation.Language.StaticParameterBinder]::BindCommand($c, $true) } catch { return $null }
  foreach ($n in $names) { if ($b.BoundParameters.ContainsKey($n)) { return $b.BoundParameters[$n] } }
  return $null
}

function q_resolve([string]$base, [string]$path) {
  if ($path -eq '~') { $path = $HOME } elseif ($path -match '^~[\\/]') { $path = Join-Path $HOME $path.Substring(2) }
  if ([System.IO.Path]::IsPathRooted($path)) { return $path }
  return Join-Path $base $path
}

# The files a path (wildcards too) names, from a folder.
function q_files([string]$base, [string]$path, [bool]$literal) {
  $full = q_resolve $base $path
  if ($literal) { $items = Get-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue }
  else { $items = Get-Item -Path $full -Force -ErrorAction SilentlyContinue }
  return @($items | Where-Object { -not $_.PSIsContainer } | ForEach-Object { $_.FullName })
}

function q_mark_read([System.Collections.Generic.List[string]]$events, [string]$file) {
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { return }
  $key = q_key $file
  if ($null -ne $key -and $key -ne '') { $events.Add("read $key") }
}

# Runs a Get-ChildItem again, in the folder it ran in, for the files it listed (it only lists).
function q_listed([string]$base, [System.Management.Automation.Language.CommandAst]$c) {
  if ((q_canonical $c) -ne 'get-childitem' -or -not (q_plain $c)) { return @() }
  Push-Location -LiteralPath $base
  try { return @(Invoke-Expression $c.Extent.Text -ErrorAction SilentlyContinue | Where-Object { $_ -is [System.IO.FileInfo] } | ForEach-Object { $_.FullName }) }
  catch { return @() }
  finally { Pop-Location }
}

# The files a Get-ChildItem earlier in the pipeline (or a foreach over one) handed to this command.
function q_upstream([string]$base, [System.Management.Automation.Language.Ast]$c) {
  $p = $c.Parent
  while ($p) {
    if ($p -is [System.Management.Automation.Language.PipelineAst] -and $p.PipelineElements.Count -gt 1) {
      $first = $p.PipelineElements[0]
      if ($first -is [System.Management.Automation.Language.CommandAst] -and $first -ne $c) { return q_listed $base $first }
    }
    if ($p -is [System.Management.Automation.Language.ForEachStatementAst]) {
      $cond = $p.Condition
      if ($cond -is [System.Management.Automation.Language.PipelineAst] -and $cond.PipelineElements[0] -is [System.Management.Automation.Language.CommandAst]) {
        return q_listed $base $cond.PipelineElements[0]
      }
    }
    $p = $p.Parent
  }
  return @()
}

# Select-String again, file names only (-List: the first match in each), on the files it searched.
function q_searched([string]$base, [System.Management.Automation.Language.CommandAst]$c, [string[]]$files) {
  if (q_bound $c @('Quiet')) { return @() }
  $pattern = q_bound $c @('Pattern')
  if (-not $pattern) { return @() }
  $patterns = q_static $pattern.Value
  if (-not $patterns) { return @() }
  $opts = @{ Pattern = $patterns; List = $true; ErrorAction = 'SilentlyContinue' }
  if (q_bound $c @('SimpleMatch')) { $opts.SimpleMatch = $true }
  if (q_bound $c @('CaseSensitive')) { $opts.CaseSensitive = $true }
  if (-not $files) { return @() }
  return @(Select-String -LiteralPath $files @opts | ForEach-Object { $_.Path })
}

# What a typed line did, in order: "enter <key>" and "read <key>". Commands used are remembered as it goes.
function q_scan([string]$line) {
  $events = [System.Collections.Generic.List[string]]::new()
  $tokens = $null; $errors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseInput($line, [ref]$tokens, [ref]$errors)
  $sim = (q_lines 'lastcwd' | Select-Object -First 1)
  if (-not $sim -or -not (Test-Path -LiteralPath $sim)) { $sim = (Get-Location -PSProvider FileSystem).ProviderPath }
  $commands = $ast.FindAll({ param($a) $a -is [System.Management.Automation.Language.CommandAst] }, $true)
  foreach ($c in $commands) {
    if ($c.InvocationOperator -eq 'Dot') {
      foreach ($v in (q_static $c.CommandElements[0])) { foreach ($f in (q_files $sim $v $true)) { q_mark_read $events $f } }
      continue
    }
    $name = $c.GetCommandName()
    if (-not $name) { continue }
    $lower = $name.ToLowerInvariant()
    $canon = q_canonical $c
    q_add 'used' $lower
    if ($canon -and $canon -ne $lower) { q_add 'used' $canon }
    if ($lower -like '*/*' -or $lower -like '*\*') { q_add 'used' ([System.IO.Path]::GetFileNameWithoutExtension($lower)) }

    if ($lower -in $script:Movers -or $canon -in @('set-location', 'push-location')) {
      $bound = q_bound $c @('Path', 'LiteralPath')
      $targets = if ($bound) { q_static $bound.Value } else { , $HOME }
      foreach ($t in $targets) {
        if ($t -in @('-', '+')) { continue }
        $dir = q_resolve $sim $t
        if (Test-Path -LiteralPath $dir -PathType Container) {
          $sim = (Resolve-Path -LiteralPath $dir).ProviderPath
          $key = q_key $sim
          if ($null -ne $key) { $events.Add("enter $key") }
        }
      }
      continue
    }

    if ($lower -in $script:Readers -or $canon -in @('get-content', 'import-csv')) {
      $bound = q_bound $c @('LiteralPath', 'Path')
      if ($bound) {
        $literal = $bound.Parameter.Name -eq 'LiteralPath'
        $values = q_static $bound.Value
        if ($values) { foreach ($v in $values) { foreach ($f in (q_files $sim $v $literal)) { q_mark_read $events $f } } }
        else { foreach ($f in (q_upstream $sim $c)) { q_mark_read $events $f } }
      } else {
        foreach ($f in (q_upstream $sim $c)) { q_mark_read $events $f }
      }
      continue
    }

    if ($lower -in $script:Searchers -or $canon -eq 'select-string') {
      $bound = q_bound $c @('LiteralPath', 'Path')
      $files = @()
      if ($bound) {
        $literal = $bound.Parameter.Name -eq 'LiteralPath'
        foreach ($v in (q_static $bound.Value)) { $files += q_files $sim $v $literal }
      } else {
        $files = q_upstream $sim $c
      }
      foreach ($f in (q_searched $sim $c $files)) { q_mark_read $events $f }
    }
  }
  # Where the player ended up, however they got there (a function, a script they dot-sourced).
  $here = (Get-Location -PSProvider FileSystem).ProviderPath
  $hereKey = q_key $here
  if ($null -ne $hereKey -and (q_key $sim) -ne $hereKey) { $events.Add("enter $hereKey") }
  return , $events
}

# ------------------------------------------------------------------------------------------------ after a command

<#
.SYNOPSIS
What runs after every command in a quest (the prompt calls it): works out what the line did in the story, fires the
story's triggers and rules, and says which treasures, goals, the coin and the finish the world now shows.
#>
function Invoke-QuestAfter([bool]$Succeeded, [string]$Line) {
  if (-not $env:QUEST_ADVENTURE) { return }
  if (-not (q_load $env:QUEST_ADVENTURE)) { return }
  if (-not (Test-Path -LiteralPath $script:QS_ROOT)) { return }
  New-Item -ItemType Directory -Force -Path $script:QS_STATE | Out-Null

  $events = q_scan $Line
  Set-Content -LiteralPath (q_file 'lastcwd') -Value (Get-Location -PSProvider FileSystem).ProviderPath
  q_forget_stopped

  foreach ($e in $events) {
    $kind, $key = $e -split ' ', 2
    if ($kind -eq 'enter') { q_add 'visits' $key }
    if ($kind -eq 'read') { q_add 'reads' $key }
    qs_fire $kind $key
  }

  for ($pass = 0; $pass -lt 10; $pass++) { if (-not (qs_rules)) { break } }

  foreach ($t in $script:QS.Treasures) {
    if ((q_treasure $t) -or -not (qs_treasure_found $t)) { continue }
    q_add 'found' $t
    $name = qs_treasure_name $t
    Write-Host ''
    q_gold "★ Treasure: $name"
    qs_treasure_text $t
    $goal = qs_treasure_goal $t
    if ($goal -and (q_has 'shown' $goal)) { q_history 'treasure' "$name (after the hint showed the command)" } else { q_history 'treasure' $name }
  }

  if ($script:QS.Coin -and -not (q_marked 'coin') -and (qs_coin_found)) {
    q_mark 'coin'
    Write-Host ''
    q_gold '◆ A rare coin!'
    qs_coin_text
    q_history 'coin' 'the rare coin'
  }

  $doneOne = $false
  foreach ($g in $script:QS.Goals) {
    if ((q_goal $g) -or -not (qs_goal_done $g)) { continue }
    q_add 'goals' $g
    $doneOne = $true
  }

  if (-not (q_marked 'finished') -and (qs_finish_when)) {
    q_mark 'finished'
    Write-Host ''
    qs_finish_text
    q_gold "★ Quest complete: $($script:QS.Title)"
    q_history 'finish' $script:QS.Title
  } elseif ($doneOne) {
    $next = q_current_goal
    if ($next) { q_dim "Next: $(qs_goal_title $next)   (stuck? quest hint)" }
  }
}

<#
.SYNOPSIS
Runs a story object (a .ps1 file that does something when run): what was piped in, its arguments, its exit code.
#>
function Invoke-QuestObject([string]$Folder, [string]$Path, [string[]]$Arguments, [string]$Stdin) {
  if (-not (q_load $Folder)) { return 127 }
  $script:QS_STDIN = $Stdin
  $code = qs_object $Path $Arguments
  return [int]($code | Select-Object -Last 1)
}

# ------------------------------------------------------------------------------------------------ the quest command

function q_all {
  . (Join-Path $env:QUEST_HOME '.quest/stories/adventures.ps1')
  return $script:QS_ALL
}

function q_find([string]$name) {
  $want = "$name".ToLowerInvariant()
  $i = 0
  foreach ($f in (q_all)) {
    $i++
    $id = (Select-String -LiteralPath (Join-Path $env:QUEST_HOME ".quest/stories/$f/story.ps1") -Pattern "^\s*Id = '(.*)'$" | Select-Object -First 1).Matches.Groups[1].Value
    if ($want -in @($f, $id, "$i", "0$i")) { return $f }
  }
  Write-Host "There is no adventure called `"$name`". These are the adventures:`n"
  quest_list
  return $null
}

function q_level([string]$level) { return (Get-Culture).TextInfo.ToTitleCase($level) }

function quest_list {
  $i = 0
  foreach ($f in (q_all)) {
    $i++
    if (-not (q_load $f)) { continue }
    $total = @($script:QS.Treasures).Count
    $found = @(q_lines 'found').Count
    if (-not (Test-Path -LiteralPath $script:QS_ROOT)) { $state = 'not started' }
    elseif (q_marked 'finished') { $state = "finished · $found of $total treasures" }
    else { $state = "in progress · $found of $total treasures" }
    if (q_marked 'coin') { $state += ' · the rare coin' }
    Write-Host ('  {0}  {1,-16} {2,-24} {3,-11} {4}' -f $i, $f, $script:QS.Title, (q_level $script:QS.Level), $state)
  }
  Write-Host "`nPlay one:  ./quest.ps1 start lighthouse"
}

# A fresh copy of an adventure: its folder, its hidden names and marks, a new run in the history.
function q_lay_out([string]$f) {
  if (-not (q_load $f)) { return $false }
  q_pause_processes
  foreach ($p in @($script:QS_ROOT, $script:QS_STATE)) { if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force } }
  New-Item -ItemType Directory -Force -Path $script:QS_ROOT, $script:QS_STATE | Out-Null
  foreach ($item in Get-ChildItem -LiteralPath (Join-Path $script:QS_DIR 'world') -Force) { Copy-Item -LiteralPath $item.FullName -Destination $script:QS_ROOT -Recurse -Force }
  q_hide_dots $script:QS_ROOT
  qs_layout
  $runs = 0
  $history = Join-Path $env:QUEST_HOME 'game-history.csv'
  if (Test-Path -LiteralPath $history) { $runs = @(Import-Csv -LiteralPath $history | Where-Object { $_.adventure -eq $f -and $_.event -eq 'start' }).Count }
  Set-Content -LiteralPath (q_file 'run') -Value ($runs + 1)
  $start = if ($script:QS.Start) { q_path $script:QS.Start } else { $script:QS_ROOT }
  Set-Content -LiteralPath (q_file 'lastcwd') -Value (q_full $start)
  qs_processes
  q_history 'start' $script:QS.Title
  return $true
}

function quest_start([string]$name) {
  if (-not $name) { Write-Host "Which adventure? For example:  ./quest.ps1 start lighthouse`n"; quest_list; return 1 }
  if ($env:QUEST_ADVENTURE) { Write-Host "You're in $env:QUEST_ADVENTURE already. Type exit to leave it, then start another."; return 1 }
  $f = q_find $name
  if (-not $f) { return 1 }
  if (-not (q_load $f)) { return 1 }
  $new = $false
  if (-not (Test-Path -LiteralPath $script:QS_ROOT) -or -not (q_marked 'run')) {
    if (-not (q_lay_out $f)) { return 1 }
    $new = $true
  }
  if ($new) {
    Write-Host (q_paint '2' (qs_art))
    Write-Host ''
    qs_intro
  } else {
    q_gold "Back in $($script:QS.Title)."
    $goal = q_current_goal
    if ($goal) { Write-Host "Your goal: $(qs_goal_title $goal)" }
  }
  Write-Host ''
  q_dim 'quest hint: a nudge · quest status: how you are doing · exit: leave (quest start brings you back)'
  Write-Host ''
  q_resume_processes
  if ($env:QUEST_NO_SHELL) { return 0 }

  # The quest's own PowerShell: your home folder is the repo, so ~ and $HOME lead to the adventures.
  $saved = @{ QUEST_ADVENTURE = $env:QUEST_ADVENTURE; QUEST_SHELL = $env:QUEST_SHELL; HOME = $env:HOME; USERPROFILE = $env:USERPROFILE }
  try {
    $env:QUEST_ADVENTURE = $f
    $env:QUEST_SHELL = 'powershell'
    $env:HOME = $env:QUEST_HOME
    if ($IsWindows) { $env:USERPROFILE = $env:QUEST_HOME }
    $session = Join-Path $env:QUEST_HOME '.quest/lib/session.ps1'
    # Start-Process, not &: the new PowerShell needs the console itself, not a pipe.
    Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList "-NoExit -NoProfile -NoLogo -File `"$session`"" -NoNewWindow -Wait
  } finally {
    foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
  }
  return 0
}

function quest_reset([string]$name) {
  if (-not $name) { Write-Host 'Which adventure? For example:  ./quest.ps1 reset lighthouse   (or --all)'; return 1 }
  if ($name -eq '--all') { $list = @(q_all | Where-Object { Test-Path -LiteralPath (Join-Path $env:QUEST_HOME $_) }) }
  else { $one = q_find $name; if (-not $one) { return 1 }; $list = @($one) }
  if ($env:QUEST_ADVENTURE -and $env:QUEST_ADVENTURE -in $list) {
    Write-Host "You're playing $env:QUEST_ADVENTURE right now. Type exit to leave it, then reset it."
    return 1
  }
  foreach ($f in $list) {
    if (-not (q_load $f)) { continue }
    if (Test-Path -LiteralPath $script:QS_ROOT) { q_history 'reset' $script:QS.Title }
    [void](q_lay_out $f)
    Write-Host "A fresh copy of $($script:QS.Title) is ready:  ./quest.ps1 start $f"
  }
  return 0
}

function quest_hint([string]$name) {
  $f = if ($env:QUEST_ADVENTURE) { $env:QUEST_ADVENTURE } else { $name }
  if (-not $f) { Write-Host 'Hints are for while you play: ./quest.ps1 start <adventure>, then quest hint.'; return 1 }
  if (-not (q_load $f)) { return 1 }
  $goal = q_current_goal
  if (-not $goal) { Write-Host 'Every goal is done. Look around for treasures you missed: quest status shows them.'; return 0 }
  $level = 1
  $last = q_lines 'hint' | Select-Object -First 1
  if ($last) {
    $g, $l = $last -split ' ', 2
    if ($g -eq $goal) { $level = [Math]::Min(3, [int]$l + 1) }
  }
  New-Item -ItemType Directory -Force -Path $script:QS_STATE | Out-Null
  Set-Content -LiteralPath (q_file 'hint') -Value "$goal $level"
  q_gold "Goal: $(qs_goal_title $goal)"
  if ($level -lt 3) {
    qs_goal_hint $goal $level
    q_dim '(quest hint again for more)'
  } else {
    qs_goal_teach $goal
    Write-Host 'Type:'
    foreach ($c in (qs_goal_solution $goal)) { Write-Host "  $c" }
    q_add 'shown' $goal
  }
  q_history 'hint' "$goal (step $level)"
  return 0
}

function quest_status([string]$name) {
  $f = if ($env:QUEST_ADVENTURE) { $env:QUEST_ADVENTURE } else { $name }
  if (-not $f) { quest_list; return 0 }
  $f = q_find $f
  if (-not $f -or -not (q_load $f)) { return 1 }
  if (-not (Test-Path -LiteralPath $script:QS_ROOT)) { Write-Host "$($script:QS.Title) isn't started yet:  ./quest.ps1 start $f"; return 0 }
  Write-Host ((q_paint '1;33' $script:QS.Title) + " · Level: $(q_level $script:QS.Level)")
  $goals = @($script:QS.Goals)
  if (q_marked 'finished') { Write-Host 'Quest complete.' }
  else {
    $goal = q_current_goal
    if ($goal) { Write-Host "Goal $([array]::IndexOf($goals, $goal) + 1) of $($goals.Count): $(qs_goal_title $goal)" }
  }
  Write-Host "`nTreasures:"
  foreach ($t in $script:QS.Treasures) {
    if (q_treasure $t) { Write-Host "  ★ $(qs_treasure_name $t)" } else { Write-Host '  ☆ not found yet' }
  }
  if ($script:QS.Coin) {
    if (q_marked 'coin') { Write-Host '  ◆ the rare coin' } else { Write-Host '  ◇ a rare coin is hidden somewhere' }
  }
  return 0
}

function quest_history([string]$name) {
  $file = Join-Path $env:QUEST_HOME 'game-history.csv'
  if (-not (Test-Path -LiteralPath $file)) { Write-Host 'No games yet. Start one:  ./quest.ps1 start lighthouse'; return 0 }
  $rows = Import-Csv -LiteralPath $file
  if ($name) { $f = q_find $name; if (-not $f) { return 1 }; $rows = $rows | Where-Object { $_.adventure -eq $f } }
  $rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
  return 0
}

function quest_usage {
  Get-Content -LiteralPath (Join-Path $env:QUEST_HOME 'quest.ps1') | Select-Object -Skip 1 -First 13 | ForEach-Object { Write-Host ($_ -replace '^# ?', '') }
}

<#
.SYNOPSIS
The quest command: list, start, reset, hint, status, history. Returns its exit code.
#>
function Invoke-Quest([string[]]$Arguments) {
  $verb = if ($Arguments.Count) { $Arguments[0] } else { '' }
  $rest = if ($Arguments.Count -gt 1) { $Arguments[1] } else { '' }
  switch ($verb) {
    'list' { quest_list; return 0 }
    'start' { return quest_start $rest }
    'reset' { return quest_reset $rest }
    'hint' { return quest_hint $rest }
    'status' { return quest_status $rest }
    'history' { return quest_history $rest }
    '__leave' { if ($env:QUEST_ADVENTURE -and (q_load $env:QUEST_ADVENTURE)) { q_pause_processes }; return 0 }
    { $_ -in @('', 'help', '-h', '--help') } { quest_usage; return 0 }
    default { Write-Host "quest: there is no `"$verb`"."; quest_usage; return 2 }
  }
}

# For the tests and the prompt: a story program's process number.
function Get-QuestPid([string]$Name) {
  if (-not (q_load $env:QUEST_ADVENTURE)) { return $null }
  return q_pid $Name
}

Export-ModuleMember -Function Invoke-QuestAfter, Invoke-QuestObject, Invoke-Quest, Get-QuestPid
