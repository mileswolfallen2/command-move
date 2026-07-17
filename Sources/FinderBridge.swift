import Cocoa

class FinderBridge {

    static func getSelectedFiles() -> [URL]? {
        return getSelectedFilesViaScript()
    }

    static func getCurrentFinderPath() -> URL? {
        let appScript = """
        tell application "Finder"
            try
                set currentFolder to (target of front Finder window) as alias
                return POSIX path of currentFolder
            on error
                return ""
            end try
        end tell
        """

        if let script = NSAppleScript(source: appScript) {
            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)
            if error == nil, let path = result.stringValue, !path.isEmpty {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private static func getSelectedFilesViaScript() -> [URL]? {
        let appScript = """
        tell application "Finder"
            try
                set selectedItems to selection
                set output to ""
                repeat with itemRef in selectedItems
                    set itemPath to POSIX path of (itemRef as alias)
                    set output to output & itemPath & linefeed
                end repeat
                return output
            on error
                return ""
            end try
        end tell
        """

        if let script = NSAppleScript(source: appScript) {
            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)
            if error == nil, let output = result.stringValue {
                let paths = output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                return paths.map { URL(fileURLWithPath: $0) }
            }
        }
        return nil
    }
}
