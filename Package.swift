// swift-tools-version: 6.0
import PackageDescription

var products: [Product] = [
    .library(name: "ZEUVECore", targets: ["ZEUVECore"]),
    .library(name: "ZEUVEStorage", targets: ["ZEUVEStorage"]),
    .library(name: "ZEUVEOperations", targets: ["ZEUVEOperations"]),
    .library(name: "ZEUVEEngines", targets: ["ZEUVEEngines"]),
    .library(name: "OrganizerModule", targets: ["OrganizerModule"]),
    .library(name: "UniversalDownloaderModule", targets: ["UniversalDownloaderModule"]),
    .library(name: "ChatAnalyzerModule", targets: ["ChatAnalyzerModule"]),
    .library(name: "UniversalConverterModule", targets: ["UniversalConverterModule"]),
    .library(name: "InstagramFollowersModule", targets: ["InstagramFollowersModule"]),
    .library(name: "MultimediaInspectorModule", targets: ["MultimediaInspectorModule"]),
    .library(name: "CleanerModule", targets: ["CleanerModule"]),
]

var targets: [Target] = [
    .systemLibrary(name: "CSQLite", path: "Sources/CSQLite"),
    .systemLibrary(name: "CLibArchive", path: "Sources/CLibArchive"),
    .target(
        name: "CZEUVEProcess",
        path: "Sources/CZEUVEProcess",
        publicHeadersPath: "include"
    ),
    .target(name: "ZEUVECore", path: "Sources/ZEUVECore"),
    .target(
        name: "ZEUVEStorage",
        dependencies: ["ZEUVECore", "CSQLite"],
        path: "Sources/ZEUVEStorage"
    ),
    .target(
        name: "ZEUVEOperations",
        dependencies: ["ZEUVECore"],
        path: "Sources/ZEUVEOperations"
    ),
    .target(
        name: "ZEUVEEngines",
        dependencies: ["ZEUVECore", "CZEUVEProcess"],
        path: "Sources/ZEUVEEngines"
    ),
    .target(
        name: "OrganizerModule",
        dependencies: ["ZEUVECore", "ZEUVEStorage", "ZEUVEOperations"],
        path: "Sources/OrganizerModule",
        resources: [.process("Resources")]
    ),
    .target(
        name: "UniversalDownloaderModule",
        dependencies: ["ZEUVECore", "ZEUVEStorage", "ZEUVEOperations", "ZEUVEEngines"],
        path: "Sources/UniversalDownloaderModule",
        resources: [.process("Resources")]
    ),
    .target(
        name: "ChatAnalyzerModule",
        dependencies: ["ZEUVECore", "ZEUVEStorage", "ZEUVEOperations", "CLibArchive"],
        path: "Sources/ChatAnalyzerModule",
        resources: [.process("Resources")]
    ),
    .target(
        name: "UniversalConverterModule",
        dependencies: ["ZEUVECore", "ZEUVEStorage", "ZEUVEOperations", "ZEUVEEngines", "CLibArchive"],
        path: "Sources/UniversalConverterModule",
        resources: [.process("Resources")]
    ),
    .target(
        name: "InstagramFollowersModule",
        dependencies: ["ZEUVECore", "ZEUVEStorage", "ZEUVEOperations", "CLibArchive"],
        path: "Sources/InstagramFollowersModule",
        resources: [.process("Resources")]
    ),
    .target(
        name: "MultimediaInspectorModule",
        dependencies: ["ZEUVECore", "ZEUVEStorage", "ZEUVEOperations", "ZEUVEEngines"],
        path: "Sources/MultimediaInspectorModule",
        resources: [.process("Resources")]
    ),
    .target(
        name: "CleanerModule",
        dependencies: ["ZEUVECore", "ZEUVEStorage", "ZEUVEOperations"],
        path: "Sources/CleanerModule",
        resources: [.process("Resources")]
    ),
    .testTarget(name: "ZEUVECoreTests", dependencies: ["ZEUVECore"], path: "Tests/ZEUVECoreTests"),
    .testTarget(name: "ZEUVEStorageTests", dependencies: ["ZEUVEStorage", "ZEUVECore"], path: "Tests/ZEUVEStorageTests"),
    .testTarget(name: "ZEUVEOperationsTests", dependencies: ["ZEUVEOperations", "ZEUVECore"], path: "Tests/ZEUVEOperationsTests"),
    .testTarget(name: "ZEUVEEnginesTests", dependencies: ["ZEUVEEngines"], path: "Tests/ZEUVEEnginesTests"),
    .testTarget(name: "OrganizerModuleTests", dependencies: ["OrganizerModule", "ZEUVEStorage", "ZEUVECore"], path: "Tests/OrganizerModuleTests"),
    .testTarget(
        name: "UniversalDownloaderModuleTests",
        dependencies: ["UniversalDownloaderModule", "ZEUVEEngines", "ZEUVEStorage", "ZEUVECore"],
        path: "Tests/UniversalDownloaderModuleTests"
    ),
    .testTarget(
        name: "ChatAnalyzerModuleTests",
        dependencies: ["ChatAnalyzerModule", "ZEUVEStorage", "ZEUVECore"],
        path: "Tests/ChatAnalyzerModuleTests"
    ),
    .testTarget(
        name: "UniversalConverterModuleTests",
        dependencies: ["UniversalConverterModule", "ZEUVEStorage", "ZEUVECore", "ZEUVEEngines"],
        path: "Tests/UniversalConverterModuleTests"
    ),
    .testTarget(
        name: "InstagramFollowersModuleTests",
        dependencies: ["InstagramFollowersModule", "ZEUVEStorage", "ZEUVECore"],
        path: "Tests/InstagramFollowersModuleTests"
    ),
    .testTarget(
        name: "MultimediaInspectorModuleTests",
        dependencies: ["MultimediaInspectorModule", "ZEUVEEngines", "ZEUVEStorage", "ZEUVECore", "ZEUVEOperations"],
        path: "Tests/MultimediaInspectorModuleTests"
    ),
    .testTarget(
        name: "CleanerModuleTests",
        dependencies: ["CleanerModule", "ZEUVEStorage", "ZEUVECore", "ZEUVEOperations"],
        path: "Tests/CleanerModuleTests"
    ),
]

let package = Package(
    name: "ZEUVE",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets,
    swiftLanguageModes: [.v6]
)
