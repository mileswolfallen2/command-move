import Cocoa

protocol HotkeyManagerDelegate: AnyObject {
    func hotkeyCut()
    func hotkeyPaste()
}

class HotkeyManager {
    weak var delegate: HotkeyManagerDelegate?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var selfRef: Unmanaged<HotkeyManager>?

    func register() {
        checkAccessibility()

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        selfRef = Unmanaged.passRetained(self)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

                if let result = manager.handleEvent(proxy: proxy, type: type, event: event) {
                    return result
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfRef?.toOpaque()
        ) else {
            print("Failed to create event tap. Check Accessibility permissions.")
            showAccessibilityAlert()
            return
        }

        self.eventTap = eventTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func unregister() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        if let ref = selfRef {
            ref.release()
            selfRef = nil
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return nil
        }

        guard type == .keyDown else { return nil }

        let flags = event.flags
        let isCommand = flags.contains(.maskCommand)
        guard isCommand else { return nil }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Cmd+X = cut
        if keyCode == 7 && isFinderFrontmost() {
            delegate?.hotkeyCut()
            return nil // consume the event so Finder doesn't get it
        }

        // Cmd+V = paste
        if keyCode == 9 && isFinderFrontmost() {
            delegate?.hotkeyPaste()
            return nil // consume the event so Finder doesn't get it
        }

        return nil
    }

    private func isFinderFrontmost() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        return frontApp.bundleIdentifier == "com.apple.finder"
    }

    private func checkAccessibility() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("Accessibility not trusted. Prompting user...")
        }
    }

    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Access Required"
            alert.informativeText = "CommandMove needs Accessibility access to intercept keyboard shortcuts in Finder.\n\nPlease grant access in System Settings > Privacy & Security > Accessibility, then restart the app."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Quit")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
            NSApplication.shared.terminate(nil)
        }
    }
}
