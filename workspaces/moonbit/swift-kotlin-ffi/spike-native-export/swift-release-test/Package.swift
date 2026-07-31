// swift-tools-version:5.9
import Foundation
import PackageDescription

let libDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("lib")
    .path

let package = Package(
    name: "ExportSpikeSwiftRelease",
    targets: [
        .systemLibrary(
            name: "CMoonBitExportRelease"
        ),
        .executableTarget(
            name: "ExportSpikeSwiftRelease",
            dependencies: ["CMoonBitExportRelease"],
            linkerSettings: [
                .unsafeFlags([
                    "-L", libDir,
                    "-lexportspike_swift_release",
                    "-Xlinker", "-rpath", "-Xlinker", libDir,
                ])
            ]
        ),
    ]
)
