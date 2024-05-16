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
    .enableExperimentalFeature("StrictConcurrency")
]

let package = Package(
    name: "swift-subprocess-distributedactors",
    platforms: [
        .macOS(.v13),
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
    ],
    targets: [
        .target(
            name: "SubprocessDistributedActors",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: swift6Mode
        ),
        .executableTarget(
            name: "Host",
            dependencies: [
                .target(name: "SubprocessDistributedActors"),
                .target(name: "Greeter")
            ],
            swiftSettings: swift6Mode
        ),
        .target(
            name: "Greeter",
            dependencies: [
                .target(name: "SubprocessDistributedActors")
            ],
            swiftSettings: swift6Mode
        ),
        .executableTarget(
            name: "EnglishGreeter",
            dependencies: [
                .target(name: "SubprocessDistributedActors"),
                .target(name: "Greeter")
            ],
            swiftSettings: swift6Mode
        ),
        .executableTarget(
            name: "FrenchGreeter",
            dependencies: [
                .target(name: "SubprocessDistributedActors"),
                .target(name: "Greeter")
            ],
            swiftSettings: swift6Mode
        ),
        .testTarget(
            name: "SubprocessDistributedActorsTests",
            dependencies: [
                .target(name: "SubprocessDistributedActors")
            ],
            swiftSettings: swift6Mode
        ),
    ]
)
