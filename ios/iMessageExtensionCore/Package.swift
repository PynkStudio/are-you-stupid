// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AYSMessageCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "AYSMessageCore", targets: ["AYSMessageCore"])],
    targets: [
        .target(name: "AYSMessageCore"),
        .testTarget(name: "AYSMessageCoreTests", dependencies: ["AYSMessageCore"]),
    ]
)
