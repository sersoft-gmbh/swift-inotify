// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let package = Package(
    name: "swift-inotify",
    platforms: [
        // These are necessary even though we don't support them.
        // The requirements are taken from swift-filestreamer.
        .macOS(.v10_13),
        .iOS(.v11),
        .tvOS(.v11),
        .watchOS(.v4),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Inotify",
            targets: ["Inotify"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-system.git", from: "1.2.0"),
        .package(url: "https://github.com/sersoft-gmbh/swift-filestreamer.git", .upToNextMinor(from: "0.5.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .systemLibrary(
            name: "CInotify"
        ),
        .target(
            name: "Inotify",
            dependencies: [
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "FileStreamer", package: "swift-filestreamer"),
                "CInotify",
            ]),
        .testTarget(
            name: "InotifyTests",
            dependencies: ["Inotify"]),
    ]
)

if ProcessInfo.processInfo.environment["ENABLE_DOCC_SUPPORT"] == "1" {
    package.dependencies.append(.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"))
}
