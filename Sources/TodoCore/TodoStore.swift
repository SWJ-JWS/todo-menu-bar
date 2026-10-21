import Foundation

/// 待办事项业务逻辑。所有写操作收敛在此，UI 层只做绑定与展示。
/// 排序规则（产品设计文档 §8）：
/// - 未完成区：done == false，按 createdAt 倒序（新记在顶部）
/// - 已完成区：done == true，按 completedAt 倒序（最近完成在顶部）
@MainActor
public final class TodoStore: ObservableObject {

    @Published public private(set) var items: [TodoItem]

    private let storage: TodoStorage

    public init(storage: TodoStorage = JSONTodoStorage()) {
        self.storage = storage
        self.items = storage.load()
    }

    /// 添加事项。空白文本直接拒绝，返回 nil。
    @discardableResult
    public func add(text: String) -> TodoItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let item = TodoItem(text: trimmed)
        items.append(item)
        persist()
        return item
    }

    /// 标记完成 / 取消完成。完成时记录 completedAt，取消时清空。
    public func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        if items[index].done {
            items[index].done = false
            items[index].completedAt = nil
        } else {
            items[index].done = true
            items[index].completedAt = .now
        }
        persist()
    }

    /// 编辑事项文字。空白文本视为无效编辑，保持原文。
    public func updateText(_ item: TodoItem, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].text = trimmed
        persist()
    }

    public func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    /// 一键清除已完成。只删 done == true 的项。
    public func clearCompleted() {
        items.removeAll { $0.done }
        persist()
    }

    /// 未完成区：按创建时间倒序，新记的在顶部。
    public var pending: [TodoItem] {
        items.filter { !$0.done }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 已完成区：按完成时间倒序，最近完成的在顶部。
    public var completed: [TodoItem] {
        items.filter { $0.done }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// 未完成数：菜单栏图标「✓ N」的数据源。
    public var pendingCount: Int {
        items.count { !$0.done }
    }

    private func persist() {
        storage.persist(items)
    }
}
