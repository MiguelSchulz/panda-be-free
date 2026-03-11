// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BambuModules",
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
    ],
    targets: [
        .target(name: "BambuModels"),
        .target(
            name: "Networking",
            dependencies: [
                "BambuModels",
                .product(name: "CocoaMQTT", package: "CocoaMQTT"),
            ]
        ),
        .target(
            name: "BambuUI",
            dependencies: ["BambuModels"]
        ),
        .target(
            name: "Onboarding",
            dependencies: [
                "BambuModels",
                "BambuUI",
                .product(name: "NavigatorUI", package: "Navigator"),
            ]
        ),
        .target(
            name: "PrinterControl",
            dependencies: [
                "BambuModels",
                "BambuUI",
                "Networking",
            ]
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
