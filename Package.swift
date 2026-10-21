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
        // 零依赖测试运行器。本机只有 Command Line Tools（无完整 Xcode），
        // XCTest 缺失、swift-testing 运行时依赖不全，官方框架均不可用，
        // 故以可执行目标跑确定性断言：swift run TodoCoreCheck（全过退出码 0）
        .executableTarget(
            name: "TodoCoreCheck",
            dependencies: ["TodoCore"],
            path: "Sources/TodoCoreCheck"
        )
    ]
)
