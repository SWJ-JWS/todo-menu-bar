import SwiftUI
import TodoCore

@main
struct TodoApp: App {

    @StateObject private var store = TodoStore()

    init() {
        GlobalHotKey.shared.register()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// 菜单栏图标：「✓ N」实时显示未完成数（产品设计文档 §6：
/// 不点开也能瞄一眼还有多少没做）。
private struct MenuBarLabel: View {
    @ObservedObject var store: TodoStore

    var body: some View {
        Text("✓ \(store.pendingCount)")
    }
}
