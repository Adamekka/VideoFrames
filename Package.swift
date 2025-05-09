// swift-tools-version: 6.0

import PackageDescription

let package: Package = .init(
    name: "VideoFrames",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .macOS(.v12),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "VideoFrames", targets: ["VideoFrames"]),
        // .executable(name: "VideoToFrames", targets: ["VideoToFrames"]),
        // .executable(name: "FramesToVideo", targets: ["FramesToVideo"]),
    ],
    dependencies: [
        // .package(url: "https://github.com/apple/swift-argument-parser", from: "0.0.1"),
    ],
    targets: [
        .target(name: "VideoFrames", dependencies: []),
        // .target(name: "VideoToFrames", dependencies: ["VideoFrames", "ArgumentParser"]),
        // .target(name: "FramesToVideo", dependencies: ["VideoFrames", "ArgumentParser"]),

        .testTarget(name: "VideoFramesTests", dependencies: ["VideoFrames"]),
    ]
)
