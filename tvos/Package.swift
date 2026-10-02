// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AYSProtocol",
    platforms: [.macOS(.v13), .tvOS(.v16), .iOS(.v16)],
    products: [
        .library(name: "AYSProtocol", targets: ["AYSProtocol"]),
        .library(name: "AYSHostCore", targets: ["AYSHostCore"]),
    ],
    targets: [
        .target(name: "AYSProtocol"),
        .testTarget(
            name: "AYSProtocolTests",
            dependencies: ["AYSProtocol"],
            resources: [.process("Fixtures")]
        ),
        .target(name: "AYSHostCore", dependencies: ["AYSProtocol"]),
        .testTarget(
            name: "AYSHostCoreTests",
            dependencies: ["AYSHostCore", "AYSProtocol"]
        ),
    ]
)
