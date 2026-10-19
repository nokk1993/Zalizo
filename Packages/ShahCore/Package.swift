// swift-tools-version: 6.0
import PackageDescription

// ShahCore holds everything that does not need UIKit/SwiftUI: models, day math,
// statistics, the repository with its cache and the HealthKit adapter.
// It is shared by the app, the widget extension and (v1.1) the Watch app,
// and its tests run with plain `swift test`, without a simulator.
let package = Package(
    name: "ShahCore",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "ShahCore", targets: ["ShahCore"]),
    ],
    targets: [
        .target(name: "ShahCore"),
        .testTarget(name: "ShahCoreTests", dependencies: ["ShahCore"]),
    ]
)
