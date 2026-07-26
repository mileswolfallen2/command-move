import Cocoa

class CutFilesService: NSObject {
    @objc func runService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        var paths: [String] = []

        if let items = pboard.pasteboardItems {
            for item in items {
                if let urlString = item.string(forType: .fileURL),
                   let url = URL(string: urlString) {
                    paths.append(url.path)
                }
            }
        }

        if paths.isEmpty, let fileNames = pboard.propertyList(forType: .string) as? String {
            paths = fileNames.components(separatedBy: "\n").filter { !$0.isEmpty }
        }

        guard !paths.isEmpty else { return }

        let sharedDefaults = UserDefaults(suiteName: "group.com.commandmove.shared")
        sharedDefaults?.set(paths, forKey: "cutFiles")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "cutTimestamp")
        sharedDefaults?.synchronize()

        DistributedNotificationCenter.default().post(
            name: NSNotification.Name("com.commandmove.cutFilesReady"),
            object: nil
        )
    }
}

let service = CutFilesService()
_ = service
CFRunLoopRun()
