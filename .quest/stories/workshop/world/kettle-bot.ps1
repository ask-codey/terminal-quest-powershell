if (-not $env:QUEST_HOME) { Write-Host 'Play this inside a quest: ./quest.ps1 start workshop'; exit 1 }
$input | & (Join-Path $env:QUEST_HOME '.quest/lib/object.ps1') 'workshop' 'kettle-bot' @args; if ($MyInvocation.InvocationName -ne '.') { exit $LASTEXITCODE }; return
# KETTLE-BOT 3000, by Ada Wren
# Needs the POWER environment variable ($env:POWER) set to "on".
# (Spare part: one golden cog, in drawer-3, in the velvet bag.)
if ($env:POWER -ne "on") { Write-Output "NO POWER"; exit 1 }
Write-Output "Pouring tea..."
