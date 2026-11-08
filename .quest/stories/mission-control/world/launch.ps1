if (-not $env:QUEST_HOME) { Write-Host 'Play this inside a quest: ./quest.ps1 start mission-control'; exit 1 }
$input | & (Join-Path $env:QUEST_HOME '.quest/lib/object.ps1') 'mission-control' 'launch' @args; if ($MyInvocation.InvocationName -ne '.') { exit $LASTEXITCODE }; return
# LAUNCH. Checks: alarm off, telemetry renamed, sensor report sent, beacon on the air.
