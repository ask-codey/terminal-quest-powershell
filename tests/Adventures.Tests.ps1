# Every adventure, played start to finish in a real PowerShell: its walkthrough finds every treasure and the coin, and
# ends the quest (the same walkthrough the online game's tests play). Pester 5.
BeforeAll { . (Join-Path $PSScriptRoot 'Helpers.ps1') }

Describe 'The adventures' {
  BeforeEach { Initialize-Quest }
  AfterEach { Clear-Quest }

  It 'The Lighthouse: every treasure, the coin, and the lamp lit' {
    Invoke-Walkthrough 'lighthouse'
    Assert-QuestComplete 'lighthouse'
  }

  It 'Moving Day: every treasure, the coin, and the new place in order' {
    Invoke-Walkthrough 'new-place'
    Assert-QuestComplete 'new-place'
  }

  It 'The Archive: every treasure, the coin, and the Star Map found' {
    Invoke-Walkthrough 'archive'
    Assert-QuestComplete 'archive'
  }

  It 'The Clockwork Workshop: every treasure, the coin, and the bell rung' {
    Invoke-Walkthrough 'workshop'
    Assert-QuestComplete 'workshop'
  }

  It 'Mission Control: every treasure, the coin, and the launch' {
    Invoke-Walkthrough 'mission-control'
    Assert-QuestComplete 'mission-control'
  }
}
