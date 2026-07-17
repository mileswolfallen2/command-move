# CommandMove

True cut & paste for files on macOS. Select files in Finder, press **Cmd+X** to cut, navigate to another folder, and press **Cmd+V** to move them.

macOS only lets you copy files, not cut them. CommandMove fixes that.

## Install

```bash
./build.sh
open build/CommandMove.app
```

Or move the app to your Applications folder:

```bash
cp -r build/CommandMove.app /Applications/
```

## Setup

On first launch, macOS will ask for **Accessibility** access:

1. Open **System Settings > Privacy & Security > Accessibility**
2. Toggle **CommandMove** on

You may also be prompted to allow **Automation** access to control Finder. Click Allow.

## Usage

| Shortcut | Action |
|----------|--------|
| **Cmd+X** | Cut selected files in Finder |
| **Cmd+V** | Paste (move) files to the current Finder folder |

The app runs in the menu bar. Click the scissors icon to cut/paste manually, clear the clipboard, or quit.

- If a file with the same name exists at the destination, it automatically appends a number (e.g. `file 2.txt`).
- Files already at the destination are skipped.

## How It Works

- **CGEvent tap** intercepts Cmd+X/Cmd+V globally and consumes the events before Finder receives them.
- **AppleScript** reads the selected files and current folder from Finder.
- **FileManager.moveItem** performs the actual file move.

## Requirements

- macOS 12.0 or later
- Accessibility permissions ( prompted on first launch )

## Building from Source

Requires only `swiftc` (comes with Xcode Command Line Tools):

```bash
./build.sh
```

This compiles the Swift sources, bundles them into a `.app`, and ad-hoc code signs it.

## License

See [LICENSE](LICENSE).
