// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swift6Mode: [SwiftSetting] = [
    .enableUpcomingFeature("BareSlashRegexLiterals"),
    .enableUpcomingFeature("ConciseMagicFile"),
    .enableUpcomingFeature("ForwardTrailingClosures"),
    .enableUpcomingFeature("ImportObjcForwardDeclarations"),
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("DeprecateApplicationMain"),
    .enableUpcomingFeature("GlobalConcurrency"),
    .enableUpcomingFeature("IsolatedDefaultValues"),
    .enableExperimentalFeature("StrictConcurrency"),
    .unsafeFlags([
        "-Xfrontend", "-disable-availability-checking",
        //"-Xfrontend", "-dump-macro-expansions"
    ])
]

let package = Package(
    name: "swift-subprocess-distributedactors",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SubprocessDistributedActors",
            targets: ["SubprocessDistributedActors"]),
        // Test projects
        .executable(name: "Host", targets: ["Host"]),
        .executable(name: "EnglishGreeter", targets: ["EnglishGreeter"]),
        .executable(name: "FrenchGreeter", targets: ["FrenchGreeter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.3"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.1"),
    ],
    targets: [
        .target(
            name: "PluginDistributedActors",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics", condition: .when(platforms: [.macOS])),
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: swift6Mode
        ),
        .target(
            name: "SubprocessDistributedActors",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .target(name: "PluginDistributedActors"),
                .product(name: "Atomics", package: "swift-atomics"),
            ],
            swiftSettings: swift6Mode
        ),
        .executableTarget(
            name: "Host",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .target(name: "SubprocessDistributedActors"),
                .target(name: "PluginDistributedActors"),
                .target(name: "Greeter"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: swift6Mode
        ),
        .target(
            name: "Greeter",
            dependencies: [
                .target(name: "PluginDistributedActors")
            ],
            swiftSettings: swift6Mode
        ),
        .executableTarget(
            name: "EnglishGreeter",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .target(name: "SubprocessDistributedActors", condition: .when(platforms: [.macOS])),
                .target(name: "Greeter")
            ],
            swiftSettings: swift6Mode
        ),
        .executableTarget(
            name: "FrenchGreeter",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .target(name: "SubprocessDistributedActors", condition: .when(platforms: [.macOS])),
                .target(name: "Greeter")
            ],
            swiftSettings: swift6Mode
        )
    ]
)
