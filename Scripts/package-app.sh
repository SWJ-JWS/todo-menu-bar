#!/bin/bash
# package-app.sh —— 构建 Release 并打包为 Todo.app
# 产物：build/Todo.app（LSUIElement=true，菜单栏常驻、无 Dock 图标）
# 用法：bash Scripts/package-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_DIR="build/Todo.app"
# 工作区在 iCloud 云盘，同步会给文件打上 FinderInfo/provenance 扩展属性，
# 导致 codesign 报 "resource fork ... not allowed"。构建产物放云盘外规避。
SCRATCH="$HOME/Library/Caches/TodoAppSPM"

echo "== 构建 Release =="
swift build --disable-sandbox -c release --scratch-path "$SCRATCH"

echo "== 组装 Todo.app =="
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$SCRATCH/release/TodoApp" "$APP_DIR/Contents/MacOS/TodoApp"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>待办清单</string>
    <key>CFBundleDisplayName</key>
    <string>待办清单</string>
    <key>CFBundleIdentifier</key>
    <string>com.jia.todo</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleExecutable</key>
    <string>TodoApp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <!-- 菜单栏常驻应用：不显示 Dock 图标 -->
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "== 临时签名（本机可运行）=="
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "（跳过签名：未配置签名环境，首次打开需右键→打开）"

echo ""
echo "完成：$APP_DIR"
echo "双击运行，或执行：open \"$APP_DIR\""
echo "提示：全局快捷键 ⌘J 唤出需在「系统设置 → 隐私与安全性 → 辅助功能」中授权。"
