import OSLog

/// Unified logging (visible in Console.app when the phone is connected).
enum Log {
    static let data = Logger(subsystem: "ua.zalizo.app", category: "data")
    static let ui = Logger(subsystem: "ua.zalizo.app", category: "ui")
}
