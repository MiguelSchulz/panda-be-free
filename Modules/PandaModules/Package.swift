// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PandaModules",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PandaModels", targets: ["PandaModels"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "PandaUI", targets: ["PandaUI"]),
        .library(name: "Onboarding", targets: ["Onboarding"]),
        .library(name: "PrinterControl", targets: ["PrinterControl"]),
    ],
    dependencies: [
        .package(url: "https://github.com/emqx/CocoaMQTT.git", from: "2.2.1"),
        .package(url: "https://github.com/hmlongco/Navigator.git", from: "2.0.0"),
        .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols.git", from: "7.0.0"),
        .package(url: "https://github.com/markiv/SwiftUI-Shimmer.git", from: "1.5.1"),
    ],
    targets: [
        .target(
            name: "PandaModels",
            dependencies: ["SFSafeSymbols"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "Networking",
            dependencies: [
                "PandaModels",
                .product(name: "CocoaMQTT", package: "CocoaMQTT"),
            ]
        ),
        .target(
            name: "PandaUI",
            dependencies: [
                "PandaModels",
                "SFSafeSymbols",
                .product(name: "Shimmer", package: "SwiftUI-Shimmer"),
            ],
            resources: [.process("Resources")]
        ),
        .target(
            name: "Onboarding",
            dependencies: [
                "PandaModels",
                "PandaUI",
                "SFSafeSymbols",
                .product(name: "NavigatorUI", package: "Navigator"),
            ],
            resources: [.process("Resources")]
        ),
        .target(
            name: "PrinterControl",
            dependencies: [
                "PandaModels",
                "PandaUI",
                "Networking",
                "SFSafeSymbols",
                .product(name: "NavigatorUI", package: "Navigator"),
                .product(name: "Shimmer", package: "SwiftUI-Shimmer"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PandaModelsTests",
            dependencies: ["PandaModels"]
        ),
        .testTarget(
            name: "OnboardingTests",
            dependencies: ["Onboarding", "PandaModels"]
        ),
        .testTarget(
            name: "PrinterControlTests",
            dependencies: ["PrinterControl", "PandaModels", "Networking"]
        ),
        .testTarget(
            name: "PandaUITests",
            dependencies: ["PandaUI", "PandaModels", "SFSafeSymbols"]
        ),
    ]
)
