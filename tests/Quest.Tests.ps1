# The quest command: the list, starting, resetting, hints, the history, and how the game notices what you read.
# Pester 5.
BeforeAll { . (Join-Path $PSScriptRoot 'Helpers.ps1') }

Describe 'quest.ps1' {
  BeforeEach { Initialize-Quest }
  AfterEach { Clear-Quest }

  It 'list: the five adventures in Level order, none started' {
    $out = Invoke-QuestCli list
    $LASTEXITCODE | Should -Be 0
    $lines = @($out -split "`r?`n" | Where-Object { $_ -and $_ -notmatch '^> ' })
    $lines[0] | Should -Match 'lighthouse\s+The Lighthouse\s+Novice\s+not started'
    $lines[4] | Should -Match 'mission-control\s+Mission Control\s+Master'
  }

  It "start: an adventure that isn't there is named, with the list" {
    $out = Invoke-QuestCli start atlantis
    $LASTEXITCODE | Should -Be 1
    $out | Should -Match 'There is no adventure called "atlantis"'
    $out | Should -Match 'The Lighthouse'
  }

  It 'start: by number, a fresh copy with its story, and a start in the history' {
    $env:QUEST_NO_SHELL = '1'
    $out = Invoke-QuestCli start 1
    $LASTEXITCODE | Should -Be 0
    $out | Should -Match 'First, find out where you are. Type Get-Location and press Enter.'
    Join-Path $TQ.Home 'lighthouse/welcome.txt' | Should -Exist
    Join-Path $TQ.Home 'lighthouse/shore/.crab-shell' | Should -Exist
    Get-Content (Join-Path $TQ.Home 'game-history.csv') -Raw | Should -Match ',lighthouse,powershell,1,start,'
  }

  It "start: inside a quest, another can't start" {
    $env:QUEST_ADVENTURE = 'lighthouse'
    $out = Invoke-QuestCli start archive
    $LASTEXITCODE | Should -Be 1
    $out | Should -Match 'Type exit to leave it'
  }

  It "reading: Get-Content counts, but Get-ChildItem, Select-String -Quiet and a missing file don't" {
    Start-QuestPlay 'lighthouse'
    Send-QuestLine 'Get-ChildItem'
    Send-QuestLine 'Select-String storm welcome.txt -Quiet'
    Send-QuestLine 'Get-Content nothing-here.txt'
    Get-QuestState 'reads' | Should -BeNullOrEmpty
    Send-QuestLine 'gc welcome.txt'
    Get-QuestState 'reads' | Should -Be 'welcome.txt'
    Get-QuestState 'goals' | Should -Contain 'look'
  }

  It 'reading: Select-String counts only the files it found a match in' {
    Start-QuestPlay 'lighthouse'
    Send-QuestLine 'Set-Location cottage'
    Send-QuestLine 'Get-ChildItem -Recurse -File | Select-String compass'
    Get-QuestState 'reads' | Should -Contain 'cottage/bedroom/diary.txt'
    Get-QuestState 'reads' | Should -Not -Contain 'cottage/kitchen/kettle.txt'
  }

  It 'reading: Get-Content on what Get-ChildItem found counts each file' {
    Start-QuestPlay 'lighthouse'
    Send-QuestLine 'Get-ChildItem cottage\kitchen -Recurse -File | ForEach-Object { Get-Content $_.FullName }'
    Get-QuestState 'reads' | Should -Contain 'cottage/kitchen/cupboard/matches.txt'
  }

  It 'moving: going into a folder tells its story once, and goals follow' {
    Start-QuestPlay 'lighthouse'
    Send-QuestLine 'cd cottage'
    ([regex]::Matches((Get-QuestLog), 'The cottage smells of salt and old books.')).Count | Should -Be 1
    Send-QuestLine 'cd ..; cd cottage'
    ([regex]::Matches((Get-QuestLog), 'The cottage smells')).Count | Should -Be 1
    Get-QuestState 'goals' | Should -Contain 'cottage'
    Get-QuestState 'used' | Should -Contain 'set-location'
  }

  It "hint: a nudge, the command's name, then the command itself" {
    Start-QuestPlay 'lighthouse'
    Invoke-QuestCli hint | Should -Match 'Ask the terminal where you are'
    Invoke-QuestCli hint | Should -Match 'Type Get-Location and press Enter.'
    Invoke-QuestCli hint | Should -Match '  Get-Location'
    @(Select-String -LiteralPath (Join-Path $TQ.Home 'game-history.csv') -Pattern ',hint,').Count | Should -Be 3
  }

  It 'status: the goal, and the treasures found and not yet' {
    Start-QuestPlay 'lighthouse'
    Send-QuestLine 'Get-Location'
    $out = Invoke-QuestCli status
    $out | Should -Match 'Goal 2 of 11: Look around'
    $out | Should -Match 'not found yet'
  }

  It 'reset: a fresh copy and a new run, and the history keeps the old one' {
    Start-QuestPlay 'lighthouse'
    Send-QuestLine 'Set-Location shore'
    Send-QuestLine 'Get-Content bottle.txt'
    Remove-Item (Join-Path $TQ.Home 'lighthouse/welcome.txt')
    $TQ.Shell.Runspace.Close()
    $TQ.Shell = $null
    Remove-Item Env:QUEST_ADVENTURE
    Invoke-QuestCli reset lighthouse | Out-Null
    $LASTEXITCODE | Should -Be 0
    Join-Path $TQ.Home 'lighthouse/welcome.txt' | Should -Exist
    Join-Path $TQ.Home '.quest/state/lighthouse/found' | Should -Not -Exist
    Get-Content (Join-Path $TQ.Home '.quest/state/lighthouse/run') | Should -Be '2'
    $history = Get-Content (Join-Path $TQ.Home 'game-history.csv') -Raw
    $history | Should -Match ',lighthouse,powershell,1,treasure,"the ship in a bottle"'
    $history | Should -Match ',lighthouse,powershell,1,reset,'
    $history | Should -Match ',lighthouse,powershell,2,start,'
  }

  It 'reset: not the adventure you are playing' {
    $env:QUEST_ADVENTURE = 'lighthouse'
    $out = Invoke-QuestCli reset lighthouse
    $LASTEXITCODE | Should -Be 1
    $out | Should -Match 'Type exit to leave it'
  }

  It 'objects: one run outside a quest says how to play' {
    $env:QUEST_NO_SHELL = '1'
    Invoke-QuestCli start workshop | Out-Null
    $saved = $env:QUEST_HOME
    Remove-Item Env:QUEST_HOME
    try {
      $out = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File (Join-Path $saved 'workshop/clock.ps1') --wind 2>&1 | Out-String
      $code = $LASTEXITCODE
    } finally { $env:QUEST_HOME = $saved }
    $code | Should -Not -Be 0
    $out | Should -Match 'Play this inside a quest: ./quest.ps1 start workshop'
  }

  It 'objects: piped text reaches the object, and its answer depends on it' {
    Start-QuestPlay 'mission-control'
    Send-QuestLine '"BEACON NOBODY" | .\transmitter.ps1'
    Get-QuestState 'flags' | Should -Not -Contain 'transmitted'
    Send-QuestLine '"BEACON KESTREL" | .\transmitter.ps1'
    Get-QuestState 'flags' | Should -Contain 'transmitted'
  }

  It "processes: a story's program runs, and Stop-Process stops it for good" {
    Start-QuestPlay 'mission-control'
    $id = Get-Content (Join-Path $TQ.Home '.quest/state/mission-control/pids/alarm')
    (Get-Process -Id $id).ProcessName | Should -Be 'alarm'
    Send-QuestLine 'Stop-Process -Name alarm'
    Start-Sleep -Milliseconds 500
    Send-QuestLine 'Get-ChildItem'
    Get-QuestState 'processes' | Should -Not -Contain 'alarm'
  }

  It 'hidden: names starting with a dot are hidden, as on Windows' {
    Start-QuestPlay 'lighthouse'
    @(Get-ChildItem (Join-Path $TQ.Home 'lighthouse/shore') | ForEach-Object Name) | Should -Not -Contain '.crab-shell'
    @(Get-ChildItem (Join-Path $TQ.Home 'lighthouse/shore') -Force | ForEach-Object Name) | Should -Contain '.crab-shell'
  }
}
