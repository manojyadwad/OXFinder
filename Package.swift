// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OXFinder",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "OXFinder", targets: ["OXFinder"])
    ],
    targets: [
        .executableTarget(
            name: "OXFinder",
            path: "Sources/OXFinder"
        )
    ]
)
