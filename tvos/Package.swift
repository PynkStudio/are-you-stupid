// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AYSProtocol",
    products: [
        .library(name: "AYSProtocol", targets: ["AYSProtocol"]),
    ],
    targets: [
        .target(name: "AYSProtocol"),
        .testTarget(
            name: "AYSProtocolTests",
            dependencies: ["AYSProtocol"],
            resources: [.process("Fixtures")]
        ),
    ]
)