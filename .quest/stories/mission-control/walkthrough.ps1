# Mission Control's walkthrough: every treasure, the coin and the finish. The tests play it. Generated: don't edit.
$script:QS_WALKTHROUGH = @(
  'Get-Content briefing.txt',
  'Get-Process',
  'Stop-Process -Name alarm',
  'Get-ChildItem -Force telemetry | Select-Object -First 3',
  'foreach ($f in Get-ChildItem telemetry\*.tmp) { Rename-Item $f.FullName ($f.BaseName + ".log") }',
  'Rename-Item telemetry\.secret.tmp .secret.log',
  'Set-Content check.ps1 @''
foreach ($f in Get-ChildItem sensors\*.txt) {
  $temp = [int]((Get-Content $f) -replace ''temp='', '''')
  if ($temp -gt 90) { $f.BaseName }
}
''@',
  '.\check.ps1',
  '.\check.ps1 | .\uplink.ps1',
  'Set-Content beacon.ps1 ''param($Callsign) "BEACON $Callsign"''',
  '.\beacon.ps1 KESTREL | .\transmitter.ps1',
  'Get-ChildItem crates -Recurse -Filter "patch-*"',
  'Get-ChildItem crates -Recurse -Filter "patch-*" | ForEach-Object { Get-Content $_.FullName }',
  'Select-String CODE message.txt | Sort-Object Line',
  '.\safe.ps1 4417',
  'New-Item -ItemType SymbolicLink -Path wallpaper -Value photos\1968\december\earthrise.txt',
  '.\viewer.ps1',
  '.\launch.ps1'
)
