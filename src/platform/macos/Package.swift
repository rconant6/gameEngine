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
      // shaders.metal is compiled by build/macos.zig into zig-out/bin/default.metallib,
      // which is what makeDefaultLibrary() loads. Excluded so SPM doesn't also
      // compile it into an unused resource bundle.
      exclude: ["shaders.metal"],
      publicHeadersPath: "include",
      cSettings: [
        .headerSearchPath("include")
      ],
    )
  ]
)
