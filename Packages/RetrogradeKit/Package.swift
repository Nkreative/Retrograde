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
        .library(name: "SurvivalKit", targets: ["SurvivalKit"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "Entitlements", targets: ["Entitlements"]),
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
        // Survival Kit content per planet and the free/Premium visibility rules.
        .target(name: "SurvivalKit", dependencies: ["RetroCore"]),
        // On-device storage (SwiftData): task completion per retrograde cycle.
        .target(name: "Persistence"),
        // Premium status: one source of truth, from purchases (simulated in M8, StoreKit in M9).
        .target(name: "Entitlements"),
        // Colours, fonts, icons and shared SwiftUI components from the Figma design.
        .target(
            name: "DesignSystem",
            resources: [.copy("Resources/Fonts")]
        ),
        .testTarget(name: "RetroCoreTests", dependencies: ["RetroCore"]),
        .testTarget(name: "AstroDataTests", dependencies: ["AstroData", "RetroCore"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "EditorialTests", dependencies: ["Editorial", "RetroCore", "AstroData"]),
        .testTarget(name: "SurvivalKitTests", dependencies: ["SurvivalKit", "RetroCore", "AstroData"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"]),
        .testTarget(name: "EntitlementsTests", dependencies: ["Entitlements", "SurvivalKit", "Persistence", "Editorial", "RetroCore", "AstroData"]),
    ]
)
