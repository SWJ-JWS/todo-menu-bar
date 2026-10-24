# 待办清单 · TodoApp

一个打开就能记、做完就划掉的 macOS 菜单栏待办工具。

核心价值只有一句话：**让「没做的事」不丢、不费脑子。**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 为什么是它

- **3 秒记录**：全局快捷键 `⌘J` 唤出，打字回车即存，全程不碰鼠标
- **随时瞄一眼**：菜单栏图标实时显示未完成数 `✓ 3`
- **做完有交代**：勾选划掉、沉到已完成区，一键清除
- **不丢字**：打了半截没回车就失焦？草稿自动暂存，下次唤出还在
- **纯本地**：无账号、无服务器，数据只存在你自己的 Mac 上

## 功能

- 添加事项（回车连记，不打断节奏）
- 事项列表（未完成在上、已完成在下，可收起）
- 标记完成 / 取消完成
- 双击编辑
- 删除（内联确认，防误删）
- 一键清除已完成
- 草稿暂存（失焦不丢）
- 本地持久化（SwiftData）

## 网页演示

仓库里的 [`demo.html`](demo.html) 是早期的**网页概念原型**（并非真实产品），
双击即可在浏览器里体验交互流程。真实 App 是 macOS 原生菜单栏应用。

## 系统要求

- macOS 14.0+
- Swift 6.0+ 工具链（推荐 Xcode 16 及以上）

## 构建与运行

```bash
# 直接运行（开发模式）
swift run

# 打包为 Todo.app（菜单栏常驻、无 Dock 图标）
bash Scripts/package-app.sh
# 产物在 build/Todo.app，双击或执行 open "build/Todo.app"
```

首次使用全局快捷键 `⌘J` 需要在「系统设置 → 隐私与安全性 → 辅助功能」中授权。

## 测试

```bash
swift test
```

测试覆盖 TodoCore 业务层：添加 / 完成 / 编辑 / 删除 / 清除、排序规则、
草稿暂存、布局计算（防回归）、旧数据迁移。

## 技术栈

| 层 | 选型 |
| --- | --- |
| UI | SwiftUI（macOS 原生） |
| 持久化 | SwiftData |
| 菜单栏 | MenuBarExtra |
| 全局快捷键 | Carbon `RegisterEventHotKey` |
| 测试 | swift-testing |

**零第三方依赖**，纯苹果 SDK。

## 项目结构

```
.
├── Sources/
│   ├── TodoApp/          # 菜单栏 UI 层（SwiftUI + AppKit）
│   └── TodoCore/         # 业务核心（数据模型 / 业务逻辑 / 草稿 / 迁移）
├── Tests/TodoCoreTests/  # swift-testing 单测
├── Scripts/              # 打包脚本
├── Package.swift
├── demo.html             # 早期网页概念原型
└── 产品设计文档.md        # 产品设计文档
```

## 许可证

[MIT](LICENSE) © 2026 嘉
