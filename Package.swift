// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LayoutRecall",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LayoutRecallKit",
            targets: ["LayoutRecallKit"]
        ),
        .executable(
            name: "LayoutRecallApp",
            targets: ["LayoutRecallApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", exact: "6.2.4")
    ],
    targets: [
        .executableTarget(
            name: "LayoutRecallApp",
            dependencies: ["LayoutRecallKit"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Combine"),
                .linkedFramework("Carbon")
            ]
        ),
        .target(
            name: "LayoutRecallKit",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ColorSync"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "LayoutRecallKitTests",
            dependencies: [
                "LayoutRecallKit",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),
        .testTarget(
            name: "LayoutRecallAppTests",
            dependencies: [
                "LayoutRecallApp",
                "LayoutRecallKit",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
