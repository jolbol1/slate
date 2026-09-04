// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SlateCore",
    platforms: [.iOS(.v12), .macOS(.v13)],
    products: [.library(name: "SlateCore", targets: ["SlateCore"])],
    targets: [
        .target(name: "SlateCore"),
        .testTarget(name: "SlateCoreTests", dependencies: ["SlateCore"])
    ]
)
