// swift-tools-version:5.9
import Foundation
import PackageDescription

let libDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("lib")
    .path

let package = Package(
    name: "ExportSpikeSwiftTest",
    targets: [
        .systemLibrary(
            name: "CMoonBitExport"
        ),
        .executableTarget(
            name: "ExportSpikeSwiftTest",
            dependencies: ["CMoonBitExport"],
            linkerSettings: [
                .unsafeFlags([
                    "-L", libDir,
                    "-lexportspike_swift",
                    "-Xlinker", "-rpath", "-Xlinker", libDir,
                ])
            ]
        ),
    ]
)
