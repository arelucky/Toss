import Foundation
import OSLog

enum TossDebugLog {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Toss",
        category: "TossDebug"
    )

    static func log(_ source: String, _ message: String) {
        #if DEBUG
        logger.debug("[\(source, privacy: .public)] \(message, privacy: .public)")
        print("[TossDebug][\(source)] \(message)")
        #endif
    }
}
