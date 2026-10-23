import Foundation
import SwiftData

/// 待办事项业务逻辑。所有写操作收敛在此，UI 层只做绑定与展示。
/// 排序规则（产品设计文档 §8）：
/// - 未完成区：done == false，按 createdAt 倒序（新记在顶部）
/// - 已完成区：done == true，按 completedAt 倒序（最近完成在顶部）
@MainActor
public struct TodoStore {

    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// 添加事项。空白文本直接拒绝，返回 nil。
    @discardableResult
    public func add(text: String) -> TodoItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let item = TodoItem(text: trimmed)
        context.insert(item)
        save()
        return item
    }

    /// 标记完成 / 取消完成。完成时记录 completedAt，取消时清空。
    public func toggle(_ item: TodoItem) {
        if item.done {
            item.done = false
            item.completedAt = nil
        } else {
            item.done = true
            item.completedAt = .now
        }
        save()
    }

    /// 编辑事项文字。空白文本视为无效编辑，保持原文。
    public func updateText(_ item: TodoItem, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        item.text = trimmed
        save()
    }

    public func delete(_ item: TodoItem) {
        context.delete(item)
        save()
    }

    /// 一键清除已完成。只删 done == true 的项。
    public func clearCompleted(_ items: [TodoItem]) {
        for item in items where item.done {
            context.delete(item)
        }
        save()
    }

    /// 未完成区：按创建时间倒序，新记的在顶部。
    public static func sortedPending(_ items: [TodoItem]) -> [TodoItem] {
        items.filter { !$0.done }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 已完成区：按完成时间倒序，最近完成的在顶部。
    public static func sortedCompleted(_ items: [TodoItem]) -> [TodoItem] {
        items.filter { $0.done }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            // SwiftData 自动保存已覆盖绝大多数场景；此处失败只可能是存储层故障，
            // 记录日志，不打断用户操作流。
            NSLog("[TodoStore] context.save() 失败: \(error)")
        }
    }
}
