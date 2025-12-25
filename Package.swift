// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NotchBuddy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "NotchBuddy",
            targets: ["NotchBuddy"]),
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "NotchBuddy",
            dependencies: [],
            path: "Sources",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]),
        .testTarget(
            name: "NotchBuddyTests",
            dependencies: ["NotchBuddy"],
            path: "Tests"),
    ]
)
