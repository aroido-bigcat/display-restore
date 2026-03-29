// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DisplayRestore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "DisplayRestoreKit",
            targets: ["DisplayRestoreKit"]
        ),
        .executable(
            name: "DisplayRestoreApp",
            targets: ["DisplayRestoreApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", exact: "6.2.4")
    ],
    targets: [
        .executableTarget(
            name: "DisplayRestoreApp",
            dependencies: ["DisplayRestoreKit"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Combine")
            ]
        ),
        .target(
            name: "DisplayRestoreKit"
        ),
        .testTarget(
            name: "DisplayRestoreKitTests",
            dependencies: [
                "DisplayRestoreKit",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
