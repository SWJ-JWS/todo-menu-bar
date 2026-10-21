import AppKit
import Carbon

/// 全局快捷键 ⌘J（产品设计文档 §6：手不离键盘秒记）。
/// 用 Carbon RegisterEventHotKey 实现，零第三方依赖（文档 §9：MVP 纯苹果 SDK）。
final class GlobalHotKey {

    static let shared = GlobalHotKey()

    private var hotKeyRef: EventHotKeyRef?

    func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userInfo in
            guard let userInfo else { return OSStatus(eventNotHandledErr) }
            Unmanaged<GlobalHotKey>.fromOpaque(userInfo)
                .takeUnretainedValue()
                .activate()
            return noErr
        }, 1, &eventType, selfPtr, nil)

        let hotKeyID = EventHotKeyID(signature: OSType(0x544F_444F), id: 1) // 'TODO'
        RegisterEventHotKey(
            UInt32(kVK_ANSI_J),
            UInt32(cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    /// 唤出浮窗：激活 App，并把菜单栏窗口提到最前成为 key window。
    /// 焦点落到输入框由 MenuBarView.onAppear / becomeKey 处理。
    private func activate() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.className.contains("MenuBarExtra") {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}
