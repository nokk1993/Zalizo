// swift-tools-version: 6.0
// ZalizoCore — pure business logic (calculations, progression, parsing, backup DTOs).
// No UIKit/SwiftUI/SwiftData imports here, so it builds and tests on macOS, iOS and Linux.
import PackageDescription

let package = Package(
    name: "ZalizoCore",
    defaultLocalization: "uk",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [
        .library(name: "ZalizoCore", targets: ["ZalizoCore"])
    ],
    targets: [
        .target(name: "ZalizoCore"),
        .testTarget(name: "ZalizoCoreTests", dependencies: ["ZalizoCore"])
    ],
    swiftLanguageModes: [.v6]
)
