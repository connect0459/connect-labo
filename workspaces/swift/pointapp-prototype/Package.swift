// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PointAppPrototype",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // ドメインロジックのみ（Pure Swift）
        .library(
            name: "PointAppDomain",
            targets: ["PointAppDomain"]
        )
    ],
    dependencies: [
        // TCAは後でアプリ層で使用
    ],
    targets: [
        // ドメイン層（Pure Swift - UIに依存しない）
        .target(
            name: "PointAppDomain",
            dependencies: [],
            path: "Sources/PointAppDomain"
        ),

        // ドメインテスト（Swift Testing）
        .testTarget(
            name: "PointAppDomainTests",
            dependencies: ["PointAppDomain"],
            path: "Tests/PointAppDomainTests"
        )
    ]
)
