import Testing
import Foundation
import SwiftData
@testable import TodoCore

/// TodoStore 业务逻辑测试（AGENTS.md：每次改动必须带测试并全部通过）。
/// 全部用内存容器跑，不碰真实存储。
///
/// 注意（踩过的坑）：ModelContext 不强持有 ModelContainer。
/// 测试里若 `let (store, _) = makeStore()` 把容器丢弃，容器立即释放，
/// 再访问 context 会 SIGTRAP 崩溃。因此用 Fixture 把容器和 Store 绑在一起持有。
@MainActor
struct TodoStoreTests {

    @MainActor
    private final class Fixture {
        let container: ModelContainer
        let store: TodoStore

        init() {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: TodoItem.self, configurations: config)
            store = TodoStore(context: container.mainContext)
        }

        func allItems() -> [TodoItem] {
            try! container.mainContext.fetch(FetchDescriptor<TodoItem>())
        }
    }

    // MARK: 添加（P0）

    @Test func add_normalText_createsItem() {
        let f = Fixture()
        let item = f.store.add(text: "买牛奶")
        #expect(item != nil)
        #expect(item?.text == "买牛奶")
        #expect(item?.done == false)
        #expect(item?.completedAt == nil)
        #expect(f.allItems().count == 1)
    }

    @Test func add_trimsWhitespace() {
        let f = Fixture()
        #expect(f.store.add(text: "  带空格  ")?.text == "带空格")
    }

    @Test func add_emptyText_rejected() {
        let f = Fixture()
        #expect(f.store.add(text: "") == nil)
        #expect(f.store.add(text: "   ") == nil)
        #expect(f.store.add(text: "\n\t") == nil)
        #expect(f.allItems().isEmpty)
    }

    // MARK: 标记完成 / 取消完成（P0）

    @Test func toggle_marksDone_withCompletedAt() throws {
        let f = Fixture()
        let item = try #require(f.store.add(text: "事项A"))
        f.store.toggle(item)
        #expect(item.done == true)
        #expect(item.completedAt != nil)
    }

    @Test func toggle_undone_clearsCompletedAt() throws {
        let f = Fixture()
        let item = try #require(f.store.add(text: "事项A"))
        f.store.toggle(item)
        f.store.toggle(item)
        #expect(item.done == false)
        #expect(item.completedAt == nil)
    }

    // MARK: 编辑（P1）

    @Test func updateText_changesText() throws {
        let f = Fixture()
        let item = try #require(f.store.add(text: "原文"))
        f.store.updateText(item, text: "新文")
        #expect(item.text == "新文")
    }

    @Test func updateText_empty_keepsOriginal() throws {
        let f = Fixture()
        let item = try #require(f.store.add(text: "原文"))
        f.store.updateText(item, text: "   ")
        #expect(item.text == "原文")
    }

    // MARK: 删除（P0）

    @Test func delete_removesItem() throws {
        let f = Fixture()
        let item = try #require(f.store.add(text: "事项A"))
        f.store.delete(item)
        #expect(f.allItems().isEmpty)
    }

    // MARK: 一键清除已完成（P1）

    @Test func clearCompleted_removesOnlyDone() throws {
        let f = Fixture()
        let a = try #require(f.store.add(text: "A"))
        let b = try #require(f.store.add(text: "B"))
        f.store.add(text: "C")
        f.store.toggle(a)
        f.store.toggle(b)
        f.store.clearCompleted(f.allItems())
        let remaining = f.allItems()
        #expect(remaining.count == 1)
        #expect(remaining.first?.text == "C")
    }

    // MARK: 排序（产品设计文档 §8）

    @Test func sortedPending_newestFirst() throws {
        let f = Fixture()
        let a = try #require(f.store.add(text: "A"))
        let b = try #require(f.store.add(text: "B"))
        let c = try #require(f.store.add(text: "C"))
        // 手动构造确定的创建时间：A 最早，C 最新
        a.createdAt = Date(timeIntervalSince1970: 100)
        b.createdAt = Date(timeIntervalSince1970: 200)
        c.createdAt = Date(timeIntervalSince1970: 300)
        #expect(TodoStore.sortedPending(f.allItems()).map(\.text) == ["C", "B", "A"])
    }

    @Test func sortedCompleted_latestCompletedFirst() throws {
        let f = Fixture()
        let a = try #require(f.store.add(text: "A"))
        let b = try #require(f.store.add(text: "B"))
        let c = try #require(f.store.add(text: "C"))
        f.store.toggle(a)
        f.store.toggle(b)
        f.store.toggle(c)
        a.completedAt = Date(timeIntervalSince1970: 100)
        b.completedAt = Date(timeIntervalSince1970: 300)
        c.completedAt = Date(timeIntervalSince1970: 200)
        #expect(TodoStore.sortedCompleted(f.allItems()).map(\.text) == ["B", "C", "A"])
    }

    @Test func sortedPending_excludesDone() throws {
        let f = Fixture()
        let a = try #require(f.store.add(text: "A"))
        f.store.add(text: "B")
        f.store.toggle(a)
        #expect(TodoStore.sortedPending(f.allItems()).map(\.text) == ["B"])
    }

    // MARK: 持久化（P0：关掉再打开数据仍在）

    @Test func persistence_roundTrip_realStore() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("todos.store")

        let config1 = ModelConfiguration(url: storeURL)
        let container1 = try ModelContainer(for: TodoItem.self, configurations: config1)
        let store1 = TodoStore(context: container1.mainContext)
        store1.add(text: "关机前记的事")

        // 模拟「关掉再打开」：新建容器，从同一文件读
        let config2 = ModelConfiguration(url: storeURL)
        let container2 = try ModelContainer(for: TodoItem.self, configurations: config2)
        let fetched = try container2.mainContext.fetch(FetchDescriptor<TodoItem>())
        #expect(fetched.map(\.text) == ["关机前记的事"])
    }
}
