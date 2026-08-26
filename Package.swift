// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "xceasy-runner",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "xceasyctl", targets: ["XCEasyCLI"])
    ],
    targets: [
        .executableTarget(name: "XCEasyCLI")
    ]
)
