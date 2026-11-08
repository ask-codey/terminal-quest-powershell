# Runs a story object (a .ps1 file that does something when run): object.ps1 <adventure> <object> [its arguments].
# Every object file hands itself here on its second line, with whatever was piped into it; the rest of the file is what
# the story shows when it's read.
param([string]$Folder, [string]$Path)
Import-Module (Join-Path $env:QUEST_HOME '.quest/lib/Quest.psm1')
$text = if ($null -ne $input) { ($input | ForEach-Object { "$_" }) -join "`n" } else { '' }
$code = Invoke-QuestObject -Folder $Folder -Path $Path -Arguments $args -Stdin $text
exit $code
