if (-not $env:QUEST_HOME) { Write-Host 'Play this inside a quest: ./quest.ps1 start workshop'; exit 1 }
$input | & (Join-Path $env:QUEST_HOME '.quest/lib/object.ps1') 'workshop' 'tools/oil' @args; if ($MyInvocation.InvocationName -ne '.') { exit $LASTEXITCODE }; return
# The oil can. Usage: oil gears
