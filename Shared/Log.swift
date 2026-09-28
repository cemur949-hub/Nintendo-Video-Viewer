import os

/// Unified logging, filterable in Console.app by subsystem = the running bundle ID.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "app"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let signing = Logger(subsystem: subsystem, category: "signing")
    static let shield = Logger(subsystem: subsystem, category: "shield")
    static let nfc = Logger(subsystem: subsystem, category: "nfc")
}
