// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TodoApp",
    platforms: [.macOS(.v14)],
    targets: [
        // 业务核心：数据模型 + 业务逻辑 + 草稿暂存，可被测试目标引用
        .target(
            name: "TodoCore",
            path: "Sources/TodoCore"
        ),
        // 菜单栏 App（SwiftUI + AppKit，UI 层不参与单测）
        .executableTarget(
            name: "TodoApp",
            dependencies: ["TodoCore"],
            path: "Sources/TodoApp"
        ),
        // swift-testing 官方测试框架（Xcode 27.1 已安装，工具链完整）
        .testTarget(
            name: "TodoCoreTests",
            dependencies: ["TodoCore"],
            path: "Tests/TodoCoreTests"
        )
    ]
)
