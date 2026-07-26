import Cocoa
import UserNotifications
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotkeyManager = HotkeyManager()
    private let fileCutPaste = FileCutPaste()
    private let menu = NSMenu()
    private var loginItemMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }

        hotkeyManager.delegate = self
        hotkeyManager.register()
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

        let statusMenuItem = NSMenuItem(title: "Waiting for Accessibility...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        statusMenuItem.tag = 200
        menu.addItem(statusMenuItem)

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

        let clipStatus = NSMenuItem(title: "No files cut", action: nil, keyEquivalent: "")
        clipStatus.isEnabled = false
        clipStatus.tag = 100
        menu.addItem(clipStatus)

        menu.addItem(NSMenuItem.separator())

        loginItemMenuItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItemMenuItem.target = self
        loginItemMenuItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItemMenuItem)

        menu.addItem(NSMenuItem.separator())

        let openSettingsItem = NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibility), keyEquivalent: "")
        openSettingsItem.target = self
        openSettingsItem.tag = 300
        menu.addItem(openSettingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit CommandMove", action: #selector(quit), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func cutFiles() {
        guard hotkeyManager.isActive else { return }
        fileCutPaste.cut()
        updateClipStatus()
    }

    @objc private func pasteFiles() {
        guard hotkeyManager.isActive else { return }
        fileCutPaste.paste()
        updateClipStatus()
    }

    @objc private func clearClipboard() {
        fileCutPaste.clear()
        updateClipStatus()
    }

    @objc private func openAccessibility() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        if service.status == .enabled {
            try? service.unregister()
        } else {
            try? service.register()
        }
        loginItemMenuItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func updateClipStatus() {
        let count = fileCutPaste.clipboardCount
        if let item = menu.items.first(where: { $0.tag == 100 }) {
            item.title = count > 0 ? "\(count) file\(count == 1 ? "" : "s") cut — ready to paste" : "No files cut"
        }
    }

    private func updateAccessibilityStatus(_ granted: Bool) {
        if let item = menu.items.first(where: { $0.tag == 200 }) {
            item.title = granted ? "Active — Cmd+X / Cmd+V ready" : "Waiting for Accessibility..."
        }
        if let item = menu.items.first(where: { $0.tag == 300 }) {
            item.isHidden = granted
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

    func accessibilityDidChange(_ granted: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.updateAccessibilityStatus(granted)
        }
    }
}
