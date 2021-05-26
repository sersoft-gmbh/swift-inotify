// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-inotify",
    platforms: [
        // These are necessary even though we don't support them.
        // The requirements are taken from swift-filestreamer.
        .macOS(.v10_12),
        .iOS(.v10),
        .tvOS(.v10),
        .watchOS(.v3),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Inotify",
            targets: ["Inotify"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-system.git", .upToNextMinor(from: "0.0.2")),
        .package(url: "https://github.com/sersoft-gmbh/swift-filestreamer.git", .upToNextMinor(from: "0.2.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .systemLibrary(
            name: "Cinotify"
        ),
        .target(
            name: "Inotify",
            dependencies: [
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "FileStreamer", package: "swift-filestreamer"),
                "Cinotify",
            ]),
        .testTarget(
            name: "InotifyTests",
            dependencies: ["Inotify"]),
    ]
)
