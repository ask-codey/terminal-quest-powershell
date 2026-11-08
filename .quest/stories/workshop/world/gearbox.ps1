if (-not $env:QUEST_HOME) { Write-Host 'Play this inside a quest: ./quest.ps1 start workshop'; exit 1 }
$input | & (Join-Path $env:QUEST_HOME '.quest/lib/object.ps1') 'workshop' 'gearbox' @args; if ($MyInvocation.InvocationName -ne '.') { exit $LASTEXITCODE }; return
# The gearbox. Needs $GEAR_SIZE (load the settings first).
