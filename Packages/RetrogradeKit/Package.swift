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
        .library(name: "Notifications", targets: ["Notifications"]),
        .library(name: "HomeWidget", targets: ["HomeWidget"]),
        .library(name: "Sharing", targets: ["Sharing"]),
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
        // Premium status: one source of truth from StoreKit 2 verified transactions (simulator in debug only).
        .target(name: "Entitlements"),
        // Notification preferences, the alert plan built from the sky data, scheduling with iOS and history.
        .target(name: "Notifications", dependencies: ["RetroCore"]),
        // What the Home Screen widget shows and when it changes, from the cycle status and Overview copy.
        .target(name: "HomeWidget", dependencies: ["RetroCore", "Editorial"]),
        // What sharing sends (app invitation, a day's insight card) and the on-device history of finished shares.
        .target(name: "Sharing", dependencies: ["RetroCore", "Editorial"]),
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
        .testTarget(name: "HomeWidgetTests", dependencies: ["HomeWidget", "RetroCore", "AstroData"]),
        .testTarget(name: "SharingTests", dependencies: ["Sharing", "Editorial", "RetroCore", "AstroData"]),
        .testTarget(name: "NotificationsTests", dependencies: ["Notifications", "RetroCore", "AstroData"]),
        .testTarget(name: "EntitlementsTests", dependencies: ["Entitlements", "SurvivalKit", "Persistence", "Editorial", "RetroCore", "AstroData"]),
    ]
)
