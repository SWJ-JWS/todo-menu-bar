import Foundation

/// 输入框草稿暂存（产品设计文档 §6「失焦即收 + 草稿暂存」、§8「草稿不进模型」）。
/// 打了半截没回车就失焦时，内容暂存到 UserDefaults，下次唤出还在。
public enum DraftStore {

    private static let key = "menuBarInputDraft"

    public static func load() -> String {
        UserDefaults.standard.string(forKey: key) ?? ""
    }

    public static func save(_ text: String) {
        UserDefaults.standard.set(text, forKey: key)
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
