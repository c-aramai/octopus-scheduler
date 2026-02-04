import Foundation

class LogService {
    private var logDirectory: String?
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
    private let fileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func configure(logDirectory: String?) {
        guard let dir = logDirectory else {
            self.logDirectory = nil
            return
        }
        let resolved = (dir as NSString).expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: resolved, withIntermediateDirectories: true)
        self.logDirectory = resolved
        log("Log service started")
    }

    func log(_ message: String, level: String = "INFO") {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level)] \(message)"

        // Always print to stdout
        print(line)

        // Write to disk if configured
        guard let dir = logDirectory else { return }
        let fileName = "octopus-\(fileDateFormatter.string(from: Date())).log"
        let filePath = (dir as NSString).appendingPathComponent(fileName)

        let lineData = (line + "\n").data(using: .utf8) ?? Data()
        if FileManager.default.fileExists(atPath: filePath) {
            if let handle = FileHandle(forWritingAtPath: filePath) {
                handle.seekToEndOfFile()
                handle.write(lineData)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: filePath, contents: lineData)
        }
    }

    func error(_ message: String) {
        log(message, level: "ERROR")
    }
}
