// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PointAppPrototype",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)  // swift testをmacOSで実行するため
    ],
    products: [
        .library(
            name: "PointAppPrototype",
            targets: ["PointAppPrototype"]
        ),
        // ドメインロジックのみ（Pure Swift）- CLIテスト用
        .library(
            name: "PointAppDomain",
            targets: ["PointAppDomain"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.15.0"
        )
    ],
    targets: [
        // ドメイン層（Pure Swift - UIに依存しない）
        .target(
            name: "PointAppDomain",
            dependencies: [],
            path: "Sources/PointAppDomain"
        ),

        // アプリ全体（SwiftUI依存）
        .target(
            name: "PointAppPrototype",
            dependencies: [
                "PointAppDomain",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            path: "Sources/PointAppPrototype"
        ),

        // ドメインテスト（Swift Testing）
        .testTarget(
            name: "PointAppDomainTests",
            dependencies: ["PointAppDomain"],
            path: "Tests/PointAppDomainTests"
        ),

        // TCA Feature テスト
        .testTarget(
            name: "PointAppPrototypeTests",
            dependencies: [
                "PointAppPrototype",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            path: "Tests/PointAppPrototypeTests"
        )
    ]
)
