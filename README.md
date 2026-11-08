# Terminal Quest for PowerShell

Text adventures you play with real PowerShell commands. Every place is a folder, every note, map and treasure is a
file, and the only way to move, look and act is to type. There are five adventures, one for each Level, from your
first `Get-Location` to writing your own scripts.

This is the PowerShell version of the game on [ask-codey.com](https://www.ask-codey.com/games/terminal-quest), where you
can play the same adventures in your browser with hints, earn XP, and find treasures and rare coins. Here you play in
a real terminal, on your own computer. Nothing you do here is sent to the site.

| # | Adventure | Level | You'll use |
|---|---|---|---|
| 1 | The Lighthouse | Novice | `Get-Location`, `Get-ChildItem`, `Set-Location`, `Get-Content`, `Get-History` |
| 2 | Moving Day | Apprentice | `New-Item`, `Copy-Item`, `Move-Item`, `Remove-Item`, `Set-Content`, wildcards |
| 3 | The Archive | Journeyman | the pipeline, `Select-String`, `Get-ChildItem -Recurse`, `Where-Object`, `Sort-Object` |
| 4 | The Clockwork Workshop | Freelancer | the execution policy, `Unblock-File`, `$env:`, `$env:PATH`, functions, dot-sourcing |
| 5 | Mission Control | Master | scripts: `foreach`, `if`, `param()`, `Get-Process`, `Stop-Process`, links |

## What you need

- **PowerShell 7** (`pwsh`), on Windows, macOS or Linux. Windows comes with Windows PowerShell 5.1, which is a
  different program: install PowerShell 7 from Microsoft (`winget install Microsoft.PowerShell` on Windows), then open
  it by typing `pwsh`.
- **Permission to run scripts.** On Windows, PowerShell only runs scripts when the *execution policy* allows it. Check
  with `Get-ExecutionPolicy`. If it says `Restricted`, let your own scripts run (this is what most developers use):

  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
  ```

  macOS and Linux have no execution policy, so there's nothing to do there.

## Get it

Clone it with git:

```powershell
git clone https://github.com/ask-codey/terminal-quest-powershell.git
cd terminal-quest-powershell
```

Or download the ZIP from GitHub and unzip it. **On Windows, a downloaded ZIP is marked as coming from the internet**, and
so is every file in it: `RemoteSigned` won't run them. If you trust it, unblock them all once, from inside the folder:

```powershell
Get-ChildItem -Recurse | Unblock-File
```

## Play

```powershell
./quest.ps1 list               # the adventures, and how far you've got in each
./quest.ps1 start lighthouse   # play one (or: ./quest.ps1 start 1)
```

`start` opens the adventure in a PowerShell of its own, with a prompt like `player@quest:~\lighthouse>`. Inside it, your
home folder (`~` and `$HOME`) is this repo, so `Set-Location ~\lighthouse` always takes you back to the start. Then type
commands: the story answers after each one.

While you play:

| Type | To |
|---|---|
| `quest hint` | get a nudge for your next goal. Again for a bigger one; a third time shows the exact command. |
| `quest status` | see your goal, the treasures you've found, and whether you've found the rare coin. |
| `exit` | leave. `./quest.ps1 start lighthouse` brings you back where you were. |

## Start again

```powershell
./quest.ps1 reset lighthouse   # a fresh copy of one adventure
./quest.ps1 reset --all        # every adventure you've started
```

A reset deletes the adventure's folder and what you did in it, then lays it out fresh. No git needed. If you're inside
the adventure, type `exit` first.

## Your history

`game-history.csv`, here at the top of the repo, keeps a row for everything that happens: each start, treasure, coin,
hint, finish and reset, with when it happened and which run it was. **A reset never clears it.**

```powershell
./quest.ps1 history              # every game
./quest.ps1 history lighthouse   # just one adventure
```

It's a plain CSV file, so try `Import-Csv game-history.csv | Group-Object event` once you reach The Archive.

## How the game knows what you did

After every command, the game looks at the real world: which folder you're in, which files exist and what they say,
your variables, environment variables, functions and running programs. What a command *read* can't be seen afterwards,
so the game reads the command you typed (with PowerShell's own parser) and notices files you read with `Get-Content`
(`gc`, `cat`, `type`), `Import-Csv`, `Select-String` (only the files it found a match in) and dot-sourcing, plus
`Get-Content` on what an earlier `Get-ChildItem` in the same pipeline found. A file read some other way, say inside a
script of your own, isn't noticed: read it with `Get-Content` to find what's in it.

## Windows, macOS and Linux

The adventures play on all three. Where they really differ:

- **Hidden files.** Names starting with a dot are hidden everywhere. On Windows the game also gives them the Hidden
  attribute when it lays an adventure out (git can't store it), so `Get-ChildItem` needs `-Force` to show them.
- **Blocked scripts** (The Clockwork Workshop). On Windows, one machine is marked as downloaded from the internet, so
  under `RemoteSigned` it won't run until you `Unblock-File` it. macOS and Linux have no such mark, so it just runs.
  `Set-ExecutionPolicy` says "not supported" on macOS and Linux; typing it still counts.
- **PATH** (The Clockwork Workshop). Windows separates the folders in `$env:PATH` with `;`, macOS and Linux with `:`.
  So off Windows, type `$env:PATH += ":$HOME/workshop/tools"`.
- **Links** (Mission Control). `New-Item -ItemType SymbolicLink` needs Developer Mode turned on (Settings, System, For
  developers) or an administrator PowerShell on Windows. Without either, a copy of the file works for the story too.
- **Programs** (Mission Control). The runaway `alarm` is a real program: Windows' own `waitfor.exe`, or `sleep` on
  macOS and Linux, copied under the name `alarm`. It only waits. It stops when you stop it, when you leave the
  adventure (it starts again when you come back) or after a day.

## Tests

The tests play every adventure's walkthrough start to finish, then check the quest command itself. They need
[Pester 5](https://pester.dev):

```powershell
pwsh -ExecutionPolicy RemoteSigned -Command "Invoke-Pester ./tests -Output Detailed"
```

They run in a temporary copy, never change your execution policy, and leave your own adventures alone.

## Licence

Terminal Quest belongs to FullStack Devs. You may play it, change your own copy, and point students to it; you may not
republish it or put it into other material without permission. See [LICENSE](LICENSE). Questions:
support@ask-codey.com.
