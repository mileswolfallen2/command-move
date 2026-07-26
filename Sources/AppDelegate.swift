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

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleServiceCutFiles),
            name: NSNotification.Name("com.commandmove.cutFilesReady"),
            object: nil
        )

        checkAppLocation()
    }

    private func checkAppLocation() {
        let appPath = Bundle.main.bundlePath
        let inApplications = appPath.hasPrefix("/Applications/") || appPath.hasPrefix(NSHomeDirectory() + "/Applications/")
        guard !inApplications else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let alert = NSAlert()
            alert.messageText = "Move to Applications?"
            alert.informativeText = "For the right-click context menu to work, CommandMove needs to be in your Applications folder.\n\nMove it there now?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Move to Applications")
            alert.addButton(withTitle: "Not Now")

            if alert.runModal() == .alertFirstButtonReturn {
                let dest = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first!
                    .appendingPathComponent("CommandMove.app")
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.moveItem(at: URL(fileURLWithPath: appPath), to: dest)
                NSWorkspace.shared.open(dest)
                NSApplication.shared.terminate(nil)
            }
        }
    }

    @objc private func handleServiceCutFiles() {
        fileCutPaste.receiveFromService()
        updateClipStatus()
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

        let openServicesItem = NSMenuItem(title: "Enable Right-Click Cut Menu", action: #selector(openServices), keyEquivalent: "")
        openServicesItem.target = self
        menu.addItem(openServicesItem)

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

    @objc private func openServices() {
        // Open System Settings > Keyboard and show instructions
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.Keyboard") {
            NSWorkspace.shared.open(url)
        }
        // Show a guide since there's no direct URL to the Services pane
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "Enable Cut Files Quick Action"
            alert.informativeText = """
            In the Keyboard settings that just opened:

            1. Click "Keyboard Shortcuts..." at the bottom
            2. Select "Services" in the left sidebar
            3. Expand "Files and Folders"
            4. Check "Cut Files (CommandMove)"

            Then right-click files in Finder → Quick Actions → Cut Files
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
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
