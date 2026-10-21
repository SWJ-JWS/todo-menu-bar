import SwiftUI
import AppKit
import TodoCore

/// 菜单栏浮窗主界面（产品设计文档 §5/§6）。
///
/// 交互回路：唤出即聚焦 → 打字 → 回车保存 → 输入框清空且焦点不丢 → 可连记。
/// Esc 或点击窗外收起；打了半截没回车就失焦时，草稿暂存，下次唤出还在。
struct MenuBarView: View {

    @EnvironmentObject private var store: TodoStore

    @State private var draft = ""
    @State private var editingID: UUID?
    @State private var editingText = ""
    @State private var pendingDeletion: TodoItem?
    @State private var confirmClearCompleted = false
    @State private var completedExpanded = true
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            inputField
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    pendingSection
                    completedSection
                }
            }
            .frame(maxHeight: 380)
        }
        .frame(width: 320)
        .onAppear {
            draft = DraftStore.load()
            NSApp.activate(ignoringOtherApps: true)
            // 唤出即就绪：浮窗出现瞬间焦点落进输入框
            DispatchQueue.main.async { inputFocused = true }
        }
        // 输入时实时暂存草稿，失焦收起也不丢
        .onChange(of: draft) { _, newValue in
            DraftStore.save(newValue)
        }
        // Esc 收起
        .onExitCommand {
            NSApp.keyWindow?.close()
        }
        // 失焦即收：App 失去激活（点到窗外/别的 App）时收起浮窗。
        // 用 didResignActive 而非 didResignKey —— 确认弹窗也是窗口，
        // 弹窗成为 key 时 App 仍在激活态，不会误收。
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didResignActiveNotification
        )) { _ in
            for window in NSApp.windows where window.className.contains("MenuBarExtra") {
                window.close()
            }
        }
        // 删除确认（P0：带确认，防误删）
        .alert("删除这条事项？", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let item = pendingDeletion {
                    store.delete(item)
                }
                pendingDeletion = nil
            }
            Button("取消", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text(pendingDeletion?.text ?? "")
        }
        // 一键清除已完成确认
        .alert("清除全部已完成事项？", isPresented: $confirmClearCompleted) {
            Button("清除 \(store.completed.count) 条", role: .destructive) {
                store.clearCompleted()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销。")
        }
    }

    // MARK: - 输入框（常驻顶部，记录是最高频动作）

    private var inputField: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.secondary)
            TextField("记一件事，回车保存…", text: $draft)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .onSubmit(submitDraft)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    /// 回车 → 保存 → 输入框清空 → 焦点留在输入框，可紧接着记第二条。
    private func submitDraft() {
        guard store.add(text: draft) != nil else { return }
        draft = ""
        DraftStore.clear()
        inputFocused = true
    }

    // MARK: - 未完成区

    private var pendingSection: some View {
        Group {
            if store.pending.isEmpty {
                Text("没有待办，回车记下第一件")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(store.pending) { item in
                    row(for: item)
                }
            }
        }
    }

    // MARK: - 已完成区（沉底，可收起）

    private var completedSection: some View {
        Group {
            if !store.completed.isEmpty {
                Divider()
                DisclosureGroup(isExpanded: $completedExpanded) {
                    ForEach(store.completed) { item in
                        row(for: item)
                    }
                    // 一键清除已完成（P1）
                    Button(role: .destructive) {
                        confirmClearCompleted = true
                    } label: {
                        Text("清除已完成（\(store.completed.count)）")
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(.vertical, 6)
                } label: {
                    Text("已完成 · \(store.completed.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
    }

    private func row(for item: TodoItem) -> TodoRow {
        TodoRow(
            item: item,
            isEditing: editingID == item.id,
            editingText: $editingText,
            onToggle: { store.toggle(item) },
            onStartEdit: {
                editingID = item.id
                editingText = item.text
            },
            onCommitEdit: {
                store.updateText(item, text: editingText)
                editingID = nil
            },
            onDelete: { pendingDeletion = item }
        )
    }
}

/// 单行事项：勾选按钮 + 文字（双击进入编辑）+ 悬停显示删除按钮。
private struct TodoRow: View {

    let item: TodoItem
    let isEditing: Bool
    @Binding var editingText: String
    let onToggle: () -> Void
    let onStartEdit: () -> Void
    let onCommitEdit: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false
    @FocusState private var editFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.done ? .green : .secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("", text: $editingText)
                    .textFieldStyle(.plain)
                    .focused($editFocused)
                    .onSubmit(onCommitEdit)
                    .onExitCommand { onCommitEdit() }
                    .onAppear { editFocused = true }
            } else {
                Text(item.text)
                    .strikethrough(item.done)
                    .foregroundStyle(item.done ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: onStartEdit)
            }

            if hovering && !isEditing {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}
