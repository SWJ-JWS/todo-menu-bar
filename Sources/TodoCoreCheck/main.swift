import Foundation
import TodoCore

// TodoCoreCheck —— 零依赖测试运行器。
// 背景：本机只有 Command Line Tools（无完整 Xcode），XCTest 缺失、
// swift-testing 的 Testing.framework 缺运行时依赖 lib_TestingInterop.dylib，
// 两种官方框架都无法跑。改用本运行器执行同一套确定性断言：
// 全部通过 → 退出码 0；任一失败 → 打印明细并以退出码 1 结束。
// 用法：swift run TodoCoreCheck

private var passCount = 0
private var failCount = 0

private func check(_ condition: Bool, _ name: String, detail: String = "") {
    if condition {
        passCount += 1
        print("  ✓ \(name)")
    } else {
        failCount += 1
        print("  ✗ \(name)\(detail.isEmpty ? "" : " —— \(detail)")")
    }
}

@MainActor
private func runAll() {
    func makeStore() -> (TodoStore, InMemoryTodoStorage) {
        let storage = InMemoryTodoStorage()
        return (TodoStore(storage: storage), storage)
    }

    // MARK: 添加（P0）
    print("添加：")
    do {
        let (store, _) = makeStore()
        let item = store.add(text: "买牛奶")
        check(item != nil && item?.text == "买牛奶" && item?.done == false
              && item?.completedAt == nil && store.items.count == 1,
              "正常文本创建事项")
    }
    do {
        let (store, _) = makeStore()
        check(store.add(text: "  带空格  ")?.text == "带空格", "首尾空白被裁剪")
    }
    do {
        let (store, _) = makeStore()
        check(store.add(text: "") == nil && store.add(text: "   ") == nil
              && store.add(text: "\n\t") == nil && store.items.isEmpty,
              "空白文本被拒绝")
    }
    do {
        let (store, storage) = makeStore()
        store.add(text: "A")
        check(storage.persistCallCount == 1 && storage.load().count == 1,
              "添加后触发持久化")
    }

    // MARK: 标记完成 / 取消完成（P0）
    print("完成/取消：")
    do {
        let (store, _) = makeStore()
        let item = store.add(text: "事项A")!
        store.toggle(item)
        let u = store.items.first { $0.id == item.id }
        check(u?.done == true && u?.completedAt != nil,
              "勾选完成：done=true 且记录 completedAt")
    }
    do {
        let (store, _) = makeStore()
        let item = store.add(text: "事项A")!
        store.toggle(item)
        store.toggle(item)
        let u = store.items.first { $0.id == item.id }
        check(u?.done == false && u?.completedAt == nil,
              "取消完成：done=false 且清空 completedAt")
    }
    do {
        let (store, _) = makeStore()
        store.add(text: "A")
        store.toggle(TodoItem(text: "不存在"))
        check(store.items.count == 1 && store.items[0].done == false,
              "未知 id 的 toggle 是无害空操作")
    }

    // MARK: 编辑（P1）
    print("编辑：")
    do {
        let (store, _) = makeStore()
        let item = store.add(text: "原文")!
        store.updateText(item, text: "新文")
        check(store.items.first?.text == "新文", "编辑更新文本")
    }
    do {
        let (store, _) = makeStore()
        let item = store.add(text: "原文")!
        store.updateText(item, text: "   ")
        check(store.items.first?.text == "原文", "空白编辑保持原文")
    }

    // MARK: 删除（P0）
    print("删除：")
    do {
        let (store, storage) = makeStore()
        let item = store.add(text: "事项A")!
        store.delete(item)
        check(store.items.isEmpty && storage.load().isEmpty,
              "删除后内存与存储同步移除")
    }

    // MARK: 一键清除已完成（P1）
    print("清除已完成：")
    do {
        let (store, _) = makeStore()
        let a = store.add(text: "A")!
        let b = store.add(text: "B")!
        store.add(text: "C")
        store.toggle(a)
        store.toggle(b)
        store.clearCompleted()
        check(store.items.count == 1 && store.items.first?.text == "C",
              "只清除已完成项")
    }

    // MARK: 排序（产品设计文档 §8）
    print("排序：")
    do {
        var a = TodoItem(text: "A"); a.createdAt = Date(timeIntervalSince1970: 100)
        var b = TodoItem(text: "B"); b.createdAt = Date(timeIntervalSince1970: 200)
        var c = TodoItem(text: "C"); c.createdAt = Date(timeIntervalSince1970: 300)
        let storage = InMemoryTodoStorage()
        storage.persist([a, b, c])
        let store = TodoStore(storage: storage)
        check(store.pending.map(\.text) == ["C", "B", "A"],
              "未完成区按 createdAt 倒序（新记在顶部）")
    }
    do {
        var a = TodoItem(text: "A"); a.done = true; a.completedAt = Date(timeIntervalSince1970: 100)
        var b = TodoItem(text: "B"); b.done = true; b.completedAt = Date(timeIntervalSince1970: 300)
        var c = TodoItem(text: "C"); c.done = true; c.completedAt = Date(timeIntervalSince1970: 200)
        let storage = InMemoryTodoStorage()
        storage.persist([a, b, c])
        let store = TodoStore(storage: storage)
        check(store.completed.map(\.text) == ["B", "C", "A"],
              "已完成区按 completedAt 倒序（最近完成在顶部）")
    }
    do {
        let (store, _) = makeStore()
        let a = store.add(text: "A")!
        store.add(text: "B")
        store.toggle(a)
        check(store.pending.map(\.text) == ["B"] && store.pendingCount == 1,
              "未完成区不含已完成项，计数正确")
    }

    // MARK: 持久化（P0：关掉再打开数据仍在）
    print("持久化：")
    do {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("todos.json")
        let store1 = TodoStore(storage: JSONTodoStorage(fileURL: file))
        store1.add(text: "关机前记的事")
        // 模拟「关掉再打开」：新建 storage + store，从同一文件读
        let store2 = TodoStore(storage: JSONTodoStorage(fileURL: file))
        check(store2.items.map(\.text) == ["关机前记的事"],
              "真实文件持久化往返一致")
    }

    // MARK: 草稿暂存（§6 失焦即收 + 草稿暂存）
    print("草稿：")
    DraftStore.clear()
    DraftStore.save("写到一半的草稿")
    check(DraftStore.load() == "写到一半的草稿", "草稿保存后可读回")
    DraftStore.clear()
    check(DraftStore.load() == "", "清除后读为空串")
}

// main.swift 顶层代码运行在主线程，用 assumeIsolated 进入 MainActor 上下文。
// （曾用 DispatchGroup.wait 等异步任务，主线程被阻塞导致死锁，勿回退。）
MainActor.assumeIsolated {
    runAll()
}

print("\n结果：\(passCount) 通过，\(failCount) 失败")
exit(failCount == 0 ? 0 : 1)
