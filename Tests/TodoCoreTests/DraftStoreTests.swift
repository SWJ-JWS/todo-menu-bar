import Testing
@testable import TodoCore

/// 草稿暂存测试（产品设计文档 §6：失焦即收 + 草稿暂存）。
/// 三个用例共享 UserDefaults 全局态，必须串行（swift-testing 默认并行会互踩）。
@Suite(.serialized)
struct DraftStoreTests {

    @Test func saveAndLoad_roundTrip() {
        DraftStore.save("写到一半的草稿")
        #expect(DraftStore.load() == "写到一半的草稿")
        DraftStore.clear()
    }

    @Test func load_emptyByDefault() {
        DraftStore.clear()
        #expect(DraftStore.load() == "")
    }

    @Test func clear_removesDraft() {
        DraftStore.save("abc")
        DraftStore.clear()
        #expect(DraftStore.load() == "")
    }
}
