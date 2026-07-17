import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotkeyManager = HotkeyManager()
    private let fileCutPaste = FileCutPaste()
    private let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()

        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }

        // Check accessibility on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hotkeyManager.delegate = self
            self.hotkeyManager.register()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "✂️"
        }
    }

    private func setupMenu() {
        let titleItem = NSMenuItem(title: "CommandMove", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        let cutItem = NSMenuItem(title: "Cut Selected Files", action: #selector(cutFiles), keyEquivalent: "x")
        cutItem.keyEquivalentModifierMask = [.command]
        cutItem.target = self
        menu.addItem(cutItem)

        let pasteItem = NSMenuItem(title: "Paste (Move Here)", action: #selector(pasteFiles), keyEquivalent: "v")
        pasteItem.keyEquivalentModifierMask = [.command]
        pasteItem.target = self
        menu.addItem(pasteItem)

        menu.addItem(NSMenuItem.separator())

        let clearItem = NSMenuItem(title: "Clear Cut Clipboard", action: #selector(clearClipboard), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(NSMenuItem.separator())

        let statusItem2 = NSMenuItem(title: "No files cut", action: nil, keyEquivalent: "")
        statusItem2.isEnabled = false
        statusItem2.tag = 100
        menu.addItem(statusItem2)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit CommandMove", action: #selector(quit), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func cutFiles() {
        fileCutPaste.cut()
        updateStatus()
    }

    @objc private func pasteFiles() {
        fileCutPaste.paste()
        updateStatus()
    }

    @objc private func clearClipboard() {
        fileCutPaste.clear()
        updateStatus()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func updateStatus() {
        let count = fileCutPaste.clipboardCount
        if let item = menu.items.first(where: { $0.tag == 100 }) {
            item.title = count > 0 ? "\(count) file\(count == 1 ? "" : "s") cut — ready to paste" : "No files cut"
        }
    }
}

extension AppDelegate: HotkeyManagerDelegate {
    func hotkeyCut() {
        DispatchQueue.main.async { [weak self] in
            self?.cutFiles()
        }
    }

    func hotkeyPaste() {
        DispatchQueue.main.async { [weak self] in
            self?.pasteFiles()
        }
    }
}
