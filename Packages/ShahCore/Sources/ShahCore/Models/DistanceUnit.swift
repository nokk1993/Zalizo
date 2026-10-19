import Foundation

public enum DistanceUnit: String, Codable, CaseIterable, Sendable {
    case kilometers
    case miles

    public var metersPerUnit: Double {
        switch self {
        case .kilometers: 1000
        case .miles: 1609.344
        }
    }

    public func value(fromMeters meters: Double) -> Double {
        meters / metersPerUnit
    }

    public func meters(fromValue value: Double) -> Double {
        value * metersPerUnit
    }

    /// Miles for the US and UK measurement systems, kilometres everywhere else.
    public static func preferred(for locale: Locale) -> DistanceUnit {
        switch locale.measurementSystem {
        case .us, .uk: .miles
        default: .kilometers
        }
    }
}
