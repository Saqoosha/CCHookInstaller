// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CCHookInstaller",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "CCHookInstaller",
            targets: ["CCHookInstaller"]
        ),
    ],
    targets: [
        .target(
            name: "CCHookInstaller"
        ),
        .testTarget(
            name: "CCHookInstallerTests",
            dependencies: ["CCHookInstaller"]
        ),
    ]
)
