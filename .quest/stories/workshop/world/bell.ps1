if (-not $env:QUEST_HOME) { Write-Host 'Play this inside a quest: ./quest.ps1 start workshop'; exit 1 }
$input | & (Join-Path $env:QUEST_HOME '.quest/lib/object.ps1') 'workshop' 'bell' @args; if ($MyInvocation.InvocationName -ne '.') { exit $LASTEXITCODE }; return
# The clock tower bell. Rings once.
# Ring it --three-times for luck.
