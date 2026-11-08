if (-not $env:QUEST_HOME) { Write-Host 'Play this inside a quest: ./quest.ps1 start mission-control'; exit 1 }
$input | & (Join-Path $env:QUEST_HOME '.quest/lib/object.ps1') 'mission-control' 'viewer' @args; if ($MyInvocation.InvocationName -ne '.') { exit $LASTEXITCODE }; return
# The photo viewer. Shows the file called wallpaper, here.
