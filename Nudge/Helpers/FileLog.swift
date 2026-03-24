import Foundation

enum FileLog {
    private static let logURL: URL = {
        let home = NSHomeDirectory()
        return URL(fileURLWithPath: "\(home)/nudge-debug.log")
    }()

    static func write(_ message: String) {
        #if DEBUG
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if let fh = try? FileHandle(forWritingTo: logURL) {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            } else {
                try? data.write(to: logURL)
            }
        }
        #endif
    }
}
