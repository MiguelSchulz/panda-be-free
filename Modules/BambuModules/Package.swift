// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BambuModules",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "BambuModels", targets: ["BambuModels"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "BambuUI", targets: ["BambuUI"]),
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
            name: "BambuModels",
            dependencies: ["SFSafeSymbols"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "Networking",
            dependencies: [
                "BambuModels",
                .product(name: "CocoaMQTT", package: "CocoaMQTT"),
            ]
        ),
        .target(
            name: "BambuUI",
            dependencies: [
                "BambuModels",
                "SFSafeSymbols",
                .product(name: "Shimmer", package: "SwiftUI-Shimmer"),
            ],
            resources: [.process("Resources")]
        ),
        .target(
            name: "Onboarding",
            dependencies: [
                "BambuModels",
                "BambuUI",
                "SFSafeSymbols",
                .product(name: "NavigatorUI", package: "Navigator"),
            ],
            resources: [.process("Resources")]
        ),
        .target(
            name: "PrinterControl",
            dependencies: [
                "BambuModels",
                "BambuUI",
                "Networking",
                "SFSafeSymbols",
                .product(name: "NavigatorUI", package: "Navigator"),
                .product(name: "Shimmer", package: "SwiftUI-Shimmer"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "BambuModelsTests",
            dependencies: ["BambuModels"]
        ),
        .testTarget(
            name: "OnboardingTests",
            dependencies: ["Onboarding", "BambuModels"]
        ),
        .testTarget(
            name: "PrinterControlTests",
            dependencies: ["PrinterControl", "BambuModels", "Networking"]
        ),
    ]
)
