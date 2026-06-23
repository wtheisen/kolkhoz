// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KolkhozSwiftUI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "KolkhozCore", targets: ["KolkhozCore"]),
        .library(name: "KolkhozAppFeature", targets: ["KolkhozAppFeature"]),
        .executable(name: "KolkhozSwiftUIApp", targets: ["KolkhozSwiftUIApp"]),
        .executable(name: "KolkhozSmokeTests", targets: ["KolkhozSmokeTests"])
    ],
    targets: [
        .target(name: "KolkhozCore"),
        .target(
            name: "KolkhozAppFeature",
            dependencies: ["KolkhozCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "KolkhozSwiftUIApp",
            dependencies: ["KolkhozAppFeature"]
        ),
        .executableTarget(
            name: "KolkhozSmokeTests",
            dependencies: ["KolkhozCore"]
        )
    ]
)
