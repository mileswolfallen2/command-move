import Cocoa

protocol HotkeyManagerDelegate: AnyObject {
    func hotkeyCut()
    func hotkeyPaste()
    func accessibilityDidChange(_ granted: Bool)
}

class HotkeyManager {
    weak var delegate: HotkeyManagerDelegate?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?
    private var isRegistered = false

    var isActive: Bool { isRegistered }

    func register() {
        // Trigger the system accessibility prompt if not yet trusted
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            createEventTap()
        } else {
            delegate?.accessibilityDidChange(false)
            startRetrying()
        }
    }

    func unregister() {
        stopRetrying()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRegistered = false
    }

    private func startRetrying() {
        stopRetrying()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.retry()
        }
    }

    private func stopRetrying() {
        retryTimer?.invalidate()
        retryTimer = nil
    }

    private func retry() {
        let trusted = AXIsProcessTrusted()
        if trusted {
            createEventTap()
        }
    }

    private func createEventTap() {
        guard !isRegistered else { return }

        // Clean up any previous attempt
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // Use a global pointer for the callback
        let ptr = Unmanaged.passRetained(self).toOpaque()

        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyCallback,
            userInfo: ptr
        ) else {
            // Tap creation failed — still not trusted or another issue
            Unmanaged<HotkeyManager>.fromOpaque(ptr).release()
            delegate?.accessibilityDidChange(false)
            if retryTimer == nil {
                startRetrying()
            }
            return
        }

        self.eventTap = eventTap
        self.isRegistered = true

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        stopRetrying()
        delegate?.accessibilityDidChange(true)
        print("Event tap registered successfully.")
    }

    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let flags = event.flags
        let isCommand = flags.contains(.maskCommand)
        guard isCommand else { return Unmanaged.passUnretained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if keyCode == 7 && isFinderFrontmost() {
            delegate?.hotkeyCut()
            return nil
        }

        if keyCode == 9 && isFinderFrontmost() {
            delegate?.hotkeyPaste()
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func isFinderFrontmost() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        return frontApp.bundleIdentifier == "com.apple.finder"
    }
}

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
    return manager.handleEvent(type: type, event: event)
}
