# Moving Day's walkthrough: every treasure, the coin and the finish. The tests play it. Generated: don't edit.
$script:QS_WALKTHROUGH = @(
  'Get-Content welcome-home.txt',
  'Get-Content hallway\packing-list.txt -TotalCount 10',
  'Get-Content hallway\packing-list.txt -Tail 1',
  'New-Item -ItemType Directory balcony\garden',
  'New-Item -ItemType Directory living-room\bookshelf',
  'Move-Item hallway\box-books\*.book living-room\bookshelf\',
  'Get-Content living-room\bookshelf\space.book',
  'Move-Item hallway\box-kitchen\* kitchen\',
  'Get-ChildItem -Force kitchen',
  'Get-Content kitchen\.under-the-sink\coin.txt',
  'Copy-Item hallway\spare-key.txt mailbox\',
  'Remove-Item hallway\broken-vase.txt, hallway\bubble-wrap.txt',
  'Remove-Item hallway\box-books, hallway\box-kitchen',
  'Move-Item hallway\box-bedroom\photo-album.txt bedroom\',
  'Get-ChildItem -Force hallway\box-bedroom\socks',
  'Get-Content hallway\box-bedroom\socks\.inside-the-blue-sock\ring.txt',
  'Set-Content door-sign.txt "Welcome to my place"',
  'Add-Content todo.txt "- water the plants"'
)
