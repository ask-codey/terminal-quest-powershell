# The Archive's walkthrough: every treasure, the coin and the finish. The tests play it. Generated: don't edit.
$script:QS_WALKTHROUGH = @(
  'Get-Content notice.txt',
  'Select-String "map-room" logs\*',
  'Select-String 7714 staff.txt',
  'Set-Content case-notes.txt "Otto Brandt"',
  'Select-String 7714 logs\* | Measure-Object',
  'Add-Content case-notes.txt 14',
  'Get-Content catalog.txt | Group-Object | Where-Object Count -gt 1',
  'Get-Content stacks\shelf-9\the-book-of-echoes.txt',
  'Get-ChildItem -Recurse -Filter "*bookmark*"',
  'Get-Content stacks\shelf-3\atlas-of-rivers\chapter-12\gold-bookmark.txt',
  'Get-ChildItem stacks -Recurse -File | Select-String "dear archivist"',
  'Get-Content stacks\shelf-6\old-letters.txt',
  'Get-ChildItem logs | Sort-Object Length | Select-Object -Last 1',
  'Get-Content logs\2026-10-31.log -Tail 1',
  'Get-ChildItem -Force reading-room',
  'Get-Content reading-room\.coat-rack\silver-coin.txt',
  'Get-ChildItem lockers -Recurse -Filter "*otto*"',
  'Set-Location lockers\basement\row-c\otto-brandt',
  'Get-ChildItem -Force',
  'Get-Content .false-bottom\star-map.txt'
)
