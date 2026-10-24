import SwiftUI
import SwiftData
import AppKit
import TodoCore

/// 菜单栏浮窗主界面（产品设计文档 §5/§6）。
///
/// 交互回路：唤出即聚焦 → 打字 → 回车保存 → 输入框清空且焦点不丢 → 可连记。
/// Esc 或点击窗外收起；打了半截没回车就失焦时，草稿暂存，下次唤出还在。
struct MenuBarView: View {

    @Environment(\.modelContext) private var context
    @Query private var items: [TodoItem]

    @State private var draft = ""
    @State private var editingID: UUID?
    @State private var editingText = ""
    @State private var completedExpanded = true
    @State private var confirmAction: ConfirmAction?
    @FocusState private var inputFocused: Bool

    /// 待确认的操作。确认条内联渲染在浮窗内，不弹窗口。
    enum ConfirmAction {
        case delete(TodoItem)
        case clearCompleted
    }

    private var store: TodoStore { TodoStore(context: context) }
    private var pending: [TodoItem] { TodoStore.sortedPending(items) }
    private var completed: [TodoItem] { TodoStore.sortedCompleted(items) }

    var body: some View {
        VStack(spacing: 0) {
            inputField
            if confirmAction != nil {
                Divider()
                confirmBar
            }
            Divider()
            // 显式算高：MenuBarExtra .window 自适应尺寸时
            // ScrollView 固有高度会塌缩为 0（列表整个消失）
            ScrollView {
                VStack(spacing: 0) {
                    pendingSection
                    completedSection
                }
            }
            .frame(height: MenuBarLayout.listHeight(
                pendingCount: pending.count,
                completedCount: completed.count,
                completedExpanded: completedExpanded
            ))
        }
        .frame(width: 320)
        .onAppear {
            draft = DraftStore.load()
            // 唤出即就绪：浮窗出现瞬间焦点落进输入框
            DispatchQueue.main.async { inputFocused = true }
        }
        // 输入时实时暂存草稿，失焦收起也不丢
        .onChange(of: draft) { _, newValue in
            DraftStore.save(newValue)
        }
        // Esc：有确认时先取消确认，无确认时收起浮窗
        .onExitCommand {
            if confirmAction != nil {
                confirmAction = nil
            } else {
                NSApp.keyWindow?.close()
            }
        }
    }

    // MARK: - 内联确认条（删除 / 清除已完成）

    /// 确认文案与执行动作。
    private var confirmTitle: String {
        switch confirmAction {
        case .delete(let item): return "删除「\(item.text)」？"
        case .clearCompleted:   return "清除 \(completed.count) 条已完成？"
        case .none:             return ""
        }
    }

    private var confirmButtonTitle: String {
        switch confirmAction {
        case .delete:          return "删除"
        case .clearCompleted:  return "清除"
        case .none:            return ""
        }
    }

    private var confirmBar: some View {
        HStack(spacing: 10) {
            Text(confirmTitle)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            Button(confirmButtonTitle) {
                executeConfirm()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .buttonStyle(.plain)
            Button("取消") {
                confirmAction = nil
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.08))
    }

    private func executeConfirm() {
        switch confirmAction {
        case .delete(let item):  store.delete(item)
        case .clearCompleted:    store.clearCompleted(completed)
        case .none:              break
        }
        confirmAction = nil
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
            if pending.isEmpty {
                Text("没有待办，回车记下第一件")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(pending) { item in
                    row(for: item)
                }
            }
        }
    }

    // MARK: - 已完成区（沉底，可收起）

    private var completedSection: some View {
        Group {
            if !completed.isEmpty {
                Divider()
                DisclosureGroup(isExpanded: $completedExpanded) {
                    ForEach(completed) { item in
                        row(for: item)
                    }
                    // 一键清除已完成（P1）
                    Button(role: .destructive) {
                        confirmClear()
                    } label: {
                        Text("清除已完成（\(completed.count)）")
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(.vertical, 6)
                } label: {
                    Text("已完成 · \(completed.count)")
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
            onDelete: { confirmDelete(item) }
        )
    }

    // MARK: - 内联确认（不弹窗口，避免关闭浮窗）

    /// 删除确认：内联确认条。MenuBarExtra 浮窗是 nonactivating 面板，
    /// SwiftUI .alert 的 sheet 按钮对鼠标点击不响应、NSAlert.runModal 又会
    /// 关闭浮窗（均已实测），故改为在浮窗内渲染确认条，最可靠。
    private func confirmDelete(_ item: TodoItem) {
        confirmAction = .delete(item)
    }

    private func confirmClear() {
        confirmAction = .clearCompleted
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
