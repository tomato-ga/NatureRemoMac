// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NatureRemoMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NatureRemoMac", targets: ["NatureRemoMac"])
    ],
    targets: [
        .executableTarget(
            name: "NatureRemoMac",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "NatureRemoMacTests",
            dependencies: ["NatureRemoMac"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
