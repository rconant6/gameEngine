// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MacPlatform",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "MacPlatform",
            type: .static,
            targets: ["MacPlatform"]
        )
    ],
    targets: [
        .target(
            name: "MacPlatform",
            path: "swift",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ]
        )
    ]
)
