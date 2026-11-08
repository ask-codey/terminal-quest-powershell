# Terminal Quest: text adventures you play with real PowerShell commands. https://www.ask-codey.com/games/terminal-quest
#
#   ./quest.ps1 list                 the adventures, and how far you've got in each
#   ./quest.ps1 start <adventure>    play one (lighthouse, or 1): a fresh copy the first time, where you left off after
#   ./quest.ps1 reset <adventure>    start it again from scratch (--all: every adventure); your history stays
#   ./quest.ps1 history              every game you've played: starts, treasures, hints, finishes and resets
#
# While you play:
#   quest hint                       a nudge for the next goal; again for more; a third time shows the command
#   quest status                     your goal, treasures and coin
#   exit                             leave the adventure (./quest.ps1 start brings you back)
#
# Copyright (c) 2026 FullStack Devs. See LICENSE.
#Requires -Version 7.0
$env:QUEST_HOME = $PSScriptRoot
Import-Module (Join-Path $PSScriptRoot '.quest/lib/Quest.psm1') -Force
$code = Invoke-Quest -Arguments $args
exit $code
