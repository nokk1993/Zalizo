import Foundation

/// Persists a single value.
public protocol ValueStore<Value>: Sendable {
    associatedtype Value: Sendable
    func load() -> Value?
    func save(_ value: Value) throws
}

/// JSON file, written atomically.
public struct JSONFileStore<Value: Codable & Sendable>: ValueStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    public func save(_ value: Value) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}

public final class InMemoryStore<Value: Sendable>: ValueStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value?

    public init(_ value: Value? = nil) {
        self.value = value
    }

    public func load() -> Value? { lock.withLock { value } }
    public func save(_ value: Value) throws { lock.withLock { self.value = value } }
}

/// `AppSettings` in `UserDefaults` (the App Group suite, so the widget sees them).
public final class SettingsStore: @unchecked Sendable {
    public static let key = "settings.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> AppSettings {
        guard let data = defaults.data(forKey: Self.key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    public func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

/// Where the app and the widget keep shared files and settings.
///
/// With the App Group entitlement both read the same container. Without it
/// (if the signing team cannot provision App Groups), each process falls back
/// to its own sandbox and the widget queries HealthKit itself.
public enum SharedContainer {
    /// Info.plist key holding the App Group ID, filled from the xcconfig.
    public static let infoKey = "ShahAppGroupID"

    public static var appGroupID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String,
              !id.isEmpty, !id.contains("$(")
        else { return nil }
        return id
    }

    /// The group container, or `nil` when the entitlement is missing.
    public static var groupDirectory: URL? {
        #if os(iOS) || os(watchOS) || os(macOS)
        guard let id = appGroupID else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
        #else
        return nil
        #endif
    }

    public static var isShared: Bool { groupDirectory != nil }

    public static var directory: URL {
        if let group = groupDirectory { return group.appendingPathComponent("Shah", isDirectory: true) }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Shah", isDirectory: true)
    }

    public static var defaults: UserDefaults {
        if isShared, let id = appGroupID, let suite = UserDefaults(suiteName: id) { return suite }
        return .standard
    }

    public static var historyCacheURL: URL { directory.appendingPathComponent("history.json") }
    public static var widgetSnapshotURL: URL { directory.appendingPathComponent("widget.json") }
}
