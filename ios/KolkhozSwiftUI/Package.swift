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
        .executable(name: "KolkhozPolicyGradientTrainer", targets: ["KolkhozPolicyGradientTrainer"]),
        .executable(name: "KolkhozPolicyBenchmark", targets: ["KolkhozPolicyBenchmark"]),
        .executable(name: "KolkhozPolicyDiagnostics", targets: ["KolkhozPolicyDiagnostics"]),
        .executable(name: "KolkhozEngineParity", targets: ["KolkhozEngineParity"]),
        .executable(name: "KolkhozEngineBenchmark", targets: ["KolkhozEngineBenchmark"]),
        .executable(name: "KolkhozOnlineServer", targets: ["KolkhozOnlineServer"])
    ],
    targets: [
        .target(
            name: "KolkhozCore",
            dependencies: ["KolkhozCEngine"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "KolkhozCEngine"
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
                .process("Assets.xcassets"),
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .executableTarget(
            name: "KolkhozSmokeTests",
            dependencies: ["KolkhozCore"]
        ),
        .executableTarget(
            name: "KolkhozPolicyGradientTrainer",
            dependencies: ["KolkhozCore", "KolkhozCEngine"]
        ),
        .executableTarget(
            name: "KolkhozPolicyBenchmark",
            dependencies: ["KolkhozCore"]
        ),
        .executableTarget(
            name: "KolkhozPolicyDiagnostics",
            dependencies: ["KolkhozCore"]
        ),
        .executableTarget(
            name: "KolkhozEngineParity",
            dependencies: ["KolkhozCore"]
        ),
        .executableTarget(
            name: "KolkhozEngineBenchmark",
            dependencies: ["KolkhozCore", "KolkhozCEngine"]
        ),
        .executableTarget(
            name: "KolkhozOnlineServer",
            dependencies: ["KolkhozCore"]
        )
    ]
)
