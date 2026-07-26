# CommandMove

CommandMove brings true cut-and-paste behavior to Finder on macOS. Select files in Finder, press Cmd+X to cut them, navigate to another folder, and press Cmd+V to move them.

macOS only supports copy-and-paste for files, not true cut-and-paste. CommandMove fills that gap.

## Features

- Global Finder shortcuts: Cmd+X to cut and Cmd+V to paste/move files
- Menu bar controls for cutting, pasting, clearing the clipboard, opening Accessibility settings, and quitting
- Optional auto-launch at login with an Open at Login toggle
- Finder right-click support through a bundled Quick Action / service for cutting files
- Automatic conflict handling: if a destination file already exists, a numbered copy is created
- Existing files at the destination are skipped safely

## Installation

1. Download the latest DMG from [Releases](releases).
2. Open the DMG and drag CommandMove to Applications.
3. Launch CommandMove from Applications.

### Build from source

If you want to build locally, run:

```bash
./build.sh
open build/CommandMove.dmg
```

The build script compiles the Swift sources, creates the app bundle, signs it ad-hoc, and produces a distributable DMG in the build directory.

## Setup

On first launch, macOS may prompt for Accessibility access:

1. Open System Settings > Privacy & Security > Accessibility
2. Enable CommandMove

You may also be prompted to allow Automation so the app can interact with Finder. Click Allow.

If you want to use the Finder right-click shortcut, make sure CommandMove is installed in your Applications folder and enable the Cut Files Quick Action from the menu bar’s Enable Right-Click Cut Menu item.

## Usage

| Shortcut / Action | Result |
|---|---|
| Cmd+X in Finder | Cuts the selected files |
| Cmd+V in Finder | Moves the cut files into the current folder |
| Menu bar icon | Lets you cut, paste, clear the clipboard, enable login launch, or open Accessibility settings |
| Finder right-click menu | Offers a Cut Files action through the bundled Quick Action / service |

## Requirements

- macOS 13.0 or later
- Accessibility permissions granted for CommandMove
- Xcode Command Line Tools (for building from source)

## How it works

- A global event tap intercepts Cmd+X and Cmd+V while Finder is frontmost.
- AppleScript queries Finder for the selected items and current folder.
- The app uses FileManager.moveItem to perform the move operation.

## License

See [LICENSE](LICENSE).
