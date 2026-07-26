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
        playChime()
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
            playChime()
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

    func receiveFromService() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.commandmove.shared")
        guard let paths = sharedDefaults?.stringArray(forKey: "cutFiles"), !paths.isEmpty else { return }

        cutFiles = paths.map { URL(fileURLWithPath: $0) }
        cutMode = true

        // Clear the shared defaults so it doesn't trigger again
        sharedDefaults?.removeObject(forKey: "cutFiles")
        sharedDefaults?.removeObject(forKey: "cutTimestamp")
        sharedDefaults?.synchronize()

        let count = cutFiles.count
        playChime()
        showNotification(
            title: "\(count) file\(count == 1 ? "" : "s") cut via context menu",
            message: "Navigate to destination folder and press Cmd+V"
        )
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

    private func playChime() {
        playSnipSound()
    }

    private func playSnipSound() {
        let sampleRate: Double = 44100

        // First snip: quick descending tone (1400Hz -> 900Hz)
        let snip1 = generateTone(
            startFreq: 1400, endFreq: 900,
            duration: 0.06, sampleRate: sampleRate,
            volume: 0.6
        )

        // Tiny gap of silence
        let gap = generateSilence(duration: 0.025, sampleRate: sampleRate)

        // Second snip: slightly lower, descending (1100Hz -> 700Hz)
        let snip2 = generateTone(
            startFreq: 1100, endFreq: 700,
            duration: 0.055, sampleRate: sampleRate,
            volume: 0.5
        )

        // Tiny click at the end for crispness
        let click = generateTone(
            startFreq: 3000, endFreq: 2000,
            duration: 0.008, sampleRate: sampleRate,
            volume: 0.3
        )

        let allSamples = snip1 + gap + snip2 + click
        guard let data = createWAVData(from: allSamples, sampleRate: sampleRate) else { return }

        let sound = NSSound(data: data)
        sound?.play()
    }

    private func generateTone(startFreq: Double, endFreq: Double, duration: Double, sampleRate: Double, volume: Double) -> [Float] {
        let totalSamples = Int(sampleRate * duration)
        var samples = [Float]()
        samples.reserveCapacity(totalSamples)

        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(totalSamples)

            // Linear frequency sweep
            let freq = startFreq + (endFreq - startFreq) * progress

            // Accumulated phase for smooth sweep
            let phase = 2.0 * .pi * freq * t

            // Sharp attack, fast decay envelope
            let envelope: Double
            if progress < 0.05 {
                envelope = progress / 0.05
            } else {
                envelope = exp(-6.0 * (progress - 0.05))
            }

            // Mix sine + slight harmonics for metallic "snip" character
            let sample = volume * envelope * (
                0.7 * sin(phase) +
                0.2 * sin(phase * 2.0) +
                0.1 * sin(phase * 3.0)
            )

            samples.append(Float(sample))
        }
        return samples
    }

    private func generateSilence(duration: Double, sampleRate: Double) -> [Float] {
        return [Float](repeating: 0, count: Int(sampleRate * duration))
    }

    private func createWAVData(from samples: [Float], sampleRate: Double) -> Data? {
        var data = Data()

        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count * 2)
        let fileSize = dataSize + 44

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        // data chunk
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

        for sample in samples {
            let clamped = max(-1.0, min(1.0, Double(sample)))
            let intSample = Int16(clamped * 32767)
            data.append(contentsOf: withUnsafeBytes(of: intSample.littleEndian) { Array($0) })
        }

        return data
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
