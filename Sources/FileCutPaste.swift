import Cocoa
import UserNotifications

class FileCutPaste {
    private var cutFiles: [URL] = []
    private var cutMode: Bool = false

    var clipboardCount: Int { cutFiles.count }

    func cut() {
        guard let files = FinderBridge.getSelectedFiles(), !files.isEmpty else {
            showNotification(title: "No files selected", message: "Select files in Finder first")
            return
        }

        cutFiles = files
        cutMode = true
        let count = files.count
        showNotification(
            title: "\(count) file\(count == 1 ? "" : "s") cut",
            message: "Navigate to destination folder and press Cmd+V"
        )
    }

    func paste() {
        guard cutMode, !cutFiles.isEmpty else { return }

        guard let destFolder = FinderBridge.getCurrentFinderPath() else {
            showNotification(title: "Error", message: "Could not determine Finder folder. Open a Finder window and try again.")
            return
        }

        let fm = FileManager.default
        var movedCount = 0
        var errors: [String] = []

        for fileURL in cutFiles {
            if !fm.fileExists(atPath: fileURL.path) {
                errors.append("\(fileURL.lastPathComponent): source not found")
                continue
            }

            let destURL = destFolder.appendingPathComponent(fileURL.lastPathComponent)

            if fileURL.deletingLastPathComponent().path == destFolder.path &&
               fileURL.path == destURL.path {
                continue
            }

            let finalDest = resolveConflict(destination: destURL, fm: fm)

            do {
                try fm.moveItem(at: fileURL, to: finalDest)
                movedCount += 1
            } catch {
                errors.append("\(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if movedCount > 0 {
            showNotification(
                title: "\(movedCount) file\(movedCount == 1 ? "" : "s") moved",
                message: "To \(destFolder.path)"
            )
        }

        if !errors.isEmpty {
            let errorMsg = errors.joined(separator: "\n")
            showNotification(title: "Errors", message: errorMsg)
        }

        clear()
    }

    func clear() {
        cutFiles.removeAll()
        cutMode = false
    }

    private func resolveConflict(destination: URL, fm: FileManager) -> URL {
        guard fm.fileExists(atPath: destination.path) else {
            return destination
        }

        let name = destination.deletingPathExtension().lastPathComponent
        let ext = destination.pathExtension
        var counter = 1
        var newURL = destination

        while fm.fileExists(atPath: newURL.path) {
            let newName = ext.isEmpty ? "\(name) \(counter)" : "\(name) \(counter).\(ext)"
            newURL = destination.deletingLastPathComponent().appendingPathComponent(newName)
            counter += 1
        }

        return newURL
    }

    private func showNotification(title: String, message: String) {
        DispatchQueue.main.async {
            let center = UNUserNotificationCenter.current()
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
