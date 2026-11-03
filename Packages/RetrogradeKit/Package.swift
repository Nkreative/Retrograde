// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RetrogradeKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RetroCore", targets: ["RetroCore"]),
        .library(name: "AstroData", targets: ["AstroData"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Editorial", targets: ["Editorial"]),
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
        // Interpretive copy (Overview now, daily insights later), kept apart from astronomical data.
        .target(name: "Editorial", dependencies: ["RetroCore"]),
        // Colours, fonts, icons and shared SwiftUI components from the Figma design.
        .target(
            name: "DesignSystem",
            resources: [.copy("Resources/Fonts")]
        ),
        .testTarget(name: "RetroCoreTests", dependencies: ["RetroCore"]),
        .testTarget(name: "AstroDataTests", dependencies: ["AstroData", "RetroCore"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "EditorialTests", dependencies: ["Editorial", "RetroCore"]),
    ]
)
