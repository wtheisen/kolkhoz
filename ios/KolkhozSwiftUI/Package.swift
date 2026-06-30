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
        .executable(name: "KolkhozSmokeTests", targets: ["KolkhozSmokeTests"]),
        .executable(name: "KolkhozPolicyEval", targets: ["KolkhozPolicyEval"]),
        .executable(name: "KolkhozRealTrainer", targets: ["KolkhozRealTrainer"]),
        .executable(name: "KolkhozPolicyBenchmark", targets: ["KolkhozPolicyBenchmark"])
    ],
    targets: [
        .target(
            name: "KolkhozCore",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "KolkhozAppFeature",
            dependencies: ["KolkhozCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "KolkhozSwiftUIApp",
            dependencies: ["KolkhozAppFeature"],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .executableTarget(
            name: "KolkhozSmokeTests",
            dependencies: ["KolkhozCore"]
        ),
        .executableTarget(
            name: "KolkhozPolicyEval",
            dependencies: ["KolkhozCore"]
        ),
        .executableTarget(
            name: "KolkhozRealTrainer",
            dependencies: ["KolkhozCore"]
        ),
        .executableTarget(
            name: "KolkhozPolicyBenchmark",
            dependencies: ["KolkhozCore"]
        )
    ]
)
