import SwiftUI
import SwiftData
import TodoCore

@main
struct TodoApp: App {

    /// 纯本地 SwiftData 持久化（产品设计文档 §9：MVP 不开 CloudKit）
    private let container: ModelContainer

    init() {
        GlobalHotKey.shared.register()
        do {
            container = try ModelContainer(for: TodoItem.self)
        } catch {
            fatalError("无法创建 SwiftData 容器: \(error)")
        }
        // 一次性导入 v0.1.0 的 JSON 旧数据（无旧数据时为空操作）
        LegacyJSONMigration.importIfNeeded(context: container.mainContext)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .modelContainer(container)
        } label: {
            MenuBarLabel()
                .modelContainer(container)
        }
        .menuBarExtraStyle(.window)
    }
}

/// 菜单栏图标：「✓ N」实时显示未完成数（产品设计文档 §6：
/// 不点开也能瞄一眼还有多少没做）。
private struct MenuBarLabel: View {
    @Query private var items: [TodoItem]

    var body: some View {
        Text("✓ \(items.count { !$0.done })")
    }
}
