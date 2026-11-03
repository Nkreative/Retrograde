// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RetrogradeKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RetroCore", targets: ["RetroCore"]),
        .library(name: "AstroData", targets: ["AstroData"]),
    ],
    targets: [
        // Planet cycles, sky events and the cycle/day calculations. No UI, no I/O.
        .target(name: "RetroCore"),
        // Loads the verified ephemeris file bundled with the app (see tools/ephemeris).
        .target(
            name: "AstroData",
            dependencies: ["RetroCore"],
            resources: [.copy("Resources/ephemeris.json")]
        ),
        .testTarget(name: "RetroCoreTests", dependencies: ["RetroCore"]),
        .testTarget(name: "AstroDataTests", dependencies: ["AstroData", "RetroCore"]),
    ]
)
