import SwiftUI
import SwiftData

struct MemoRootView: View {
    var body: some View {
        #if os(macOS)
        MemoBoardView()
        #else
        MemoListNavigationView()
        #endif
    }
}

#if os(macOS)
struct MemoBoardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\MemoEntry.updatedAt, order: .reverse)])
    private var memos: [MemoEntry]
    @State private var selectedMemoID: UUID?
    @State private var searchText = ""
    @State private var pendingCreatedMemo: MemoEntry?
    @State private var isListVisible = true

    private var filteredMemos: [MemoEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return memos }
        return memos.filter {
            $0.displayTitle.lowercased().contains(query) ||
            $0.plainText.lowercased().contains(query)
        }
    }

    private var selectedMemo: MemoEntry? {
        let isSearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if let pendingCreatedMemo, pendingCreatedMemo.id == selectedMemoID {
            return pendingCreatedMemo
        }
        guard !filteredMemos.isEmpty else { return nil }
        guard let selectedMemoID else { return filteredMemos.first }
        if isSearching {
            return filteredMemos.first { $0.id == selectedMemoID } ?? filteredMemos.first
        }
        return memos.first { $0.id == selectedMemoID } ?? filteredMemos.first
    }

    var body: some View {
        MascotCornerContainer {
            Group {
                if isListVisible {
                    HSplitView {
                        MemoSidebarView(
                            memos: filteredMemos,
                            selectedMemoID: $selectedMemoID,
                            searchText: $searchText,
                            createAction: createMemo,
                            deleteAction: deleteMemos
                        )
                        .frame(minWidth: 280, idealWidth: 330, maxWidth: 390)

                        detailPane
                    }
                } else {
                    detailPane
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("随记")
        .onAppear {
            if selectedMemoID == nil {
                selectedMemoID = memos.first?.id
            }
        }
        .onChange(of: searchText) { _, _ in
            selectedMemoID = selectedMemo?.id
        }
        .onChange(of: selectedMemoID) { _, newValue in
            if newValue != nil {
                isListVisible = false
            }
        }
        .onChange(of: memos.map(\.id)) { _, ids in
            if let pendingCreatedMemo, ids.contains(pendingCreatedMemo.id) {
                self.pendingCreatedMemo = nil
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        Group {
            if let selectedMemo {
                MemoEditorView(
                    memo: selectedMemo,
                    isListVisible: isListVisible,
                    toggleListAction: { isListVisible.toggle() }
                )
                .id(selectedMemo.id)
            } else {
                MemoEmptyDetailView(
                    isSearching: !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    createAction: createMemo
                )
            }
        }
        .frame(minWidth: 520)
    }

    private func createMemo() {
        let memo = MemoEntry()
        modelContext.insert(memo)
        searchText = ""
        pendingCreatedMemo = memo
        selectedMemoID = memo.id
        isListVisible = false
        try? modelContext.save()
    }

    private func deleteMemos(at offsets: IndexSet) {
        let deletedIDs = offsets.map { filteredMemos[$0].id }
        for index in offsets {
            modelContext.delete(filteredMemos[index])
        }
        selectedMemoID = filteredMemos.first { !deletedIDs.contains($0.id) }?.id
        if selectedMemoID == nil {
            isListVisible = true
        }
        try? modelContext.save()
    }
}

private struct MemoSidebarView: View {
    let memos: [MemoEntry]
    @Binding var selectedMemoID: UUID?
    @Binding var searchText: String
    let createAction: () -> Void
    let deleteAction: (IndexSet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("随记")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: createAction) {
                    Label("新建随记", systemImage: "square.and.pencil")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .help("新建随记")
            }

            TextField("搜索随记...", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if memos.isEmpty {
                MemoListEmptyView(
                    isSearching: !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    createAction: createAction
                )
            } else {
                List(selection: $selectedMemoID) {
                    ForEach(memos) { memo in
                        MemoCompactRowView(memo: memo)
                            .tag(memo.id)
                    }
                    .onDelete(perform: deleteAction)
                }
                .listStyle(.sidebar)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.secondarySystemBackground.opacity(0.35))
    }
}

private struct MemoListEmptyView: View {
    let isSearching: Bool
    let createAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isSearching ? "magnifyingglass" : "square.and.pencil")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.secondary)

            Text(isSearching ? "没有匹配的随记" : "还没有随记")
                .font(.headline)

            if !isSearching {
                Button(action: createAction) {
                    Label("新建随记", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MemoEmptyDetailView: View {
    let isSearching: Bool
    let createAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: isSearching ? "magnifyingglass" : "square.and.pencil")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.secondary)

            Text(isSearching ? "没有匹配的随记" : "还没有随记")
                .font(.title)
                .fontWeight(.semibold)

            Text(isSearching ? "换个关键词试试" : "写点零散想法，慢慢长成自己的小册子。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !isSearching {
                Button(action: createAction) {
                    Label("新建随记", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondarySystemBackground.opacity(0.45))
    }
}
#endif

struct MemoListNavigationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\MemoEntry.updatedAt, order: .reverse)])
    private var memos: [MemoEntry]
    @State private var searchText = ""
    @State private var editingMemo: MemoEntry?

    private var filteredMemos: [MemoEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return memos }
        return memos.filter {
            $0.displayTitle.lowercased().contains(query) ||
            $0.plainText.lowercased().contains(query)
        }
    }

    var body: some View {
        MascotCornerContainer {
            List {
                ForEach(filteredMemos) { memo in
                    NavigationLink {
                        MemoEditorView(memo: memo)
                    } label: {
                        MemoRowView(memo: memo)
                    }
                }
                .onDelete(perform: deleteMemos)
            }
            .overlay {
                if memos.isEmpty {
                    EmptyStateView(
                        icon: "square.and.pencil",
                        title: "还没有随记",
                        subtitle: "点击右上角按钮开始记录"
                    )
                }
            }
            .searchable(text: $searchText, prompt: "搜索随记...")
        }
        .navigationTitle("随记")
        .toolbar {
            ToolbarItem {
                Button {
                    createMemo()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(item: $editingMemo) { memo in
            NavigationStack {
                MemoEditorView(memo: memo)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") {
                                editingMemo = nil
                            }
                        }
                    }
            }
        }
    }

    private func createMemo() {
        let memo = MemoEntry()
        modelContext.insert(memo)
        searchText = ""
        editingMemo = memo
        try? modelContext.save()
    }

    private func deleteMemos(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredMemos[index])
        }
        try? modelContext.save()
    }
}

struct MemoEditorView: View {
    @Bindable var memo: MemoEntry
    var isListVisible = true
    var toggleListAction: (() -> Void)?
    @StateObject private var markdownCommands = MarkdownEditorCommands()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    if let toggleListAction {
                        Button(action: toggleListAction) {
                            Label(isListVisible ? "收起列表" : "显示列表", systemImage: "sidebar.leading")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.bordered)
                        .help(isListVisible ? "收起列表" : "显示列表")
                    }

                    TextField("标题", text: Binding(
                        get: { memo.title },
                        set: {
                            memo.title = $0
                            memo.updatedAt = Date()
                        }
                    ))
                    .font(.title)
                    .textFieldStyle(.plain)
                }

                MemoFormatToolbar(commands: markdownCommands)
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()
                .padding(.horizontal)
                .padding(.top, 8)

            TyporaEditorView(
                text: Binding(
                    get: { memo.plainText },
                    set: {
                        memo.plainText = $0
                        memo.richTextData = nil
                        memo.updatedAt = Date()
                    }
                ),
                commands: markdownCommands
            )
            .overlay(alignment: .topLeading) {
                if memo.plainText.isEmpty {
                    Text("写一点 Markdown...")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 18)
                        .padding(.leading, 28)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.secondarySystemBackground.opacity(0.45))
        .navigationTitle(memo.displayTitle)
    }
}

private struct MemoFormatToolbar: View {
    let commands: MarkdownEditorCommands

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    commands.apply(.heading)
                } label: {
                    Image(systemName: "number")
                }
                .help("标题")

                Button {
                    commands.apply(.bold)
                } label: {
                    Image(systemName: "bold")
                }
                .help("粗体")

                Button {
                    commands.apply(.italic)
                } label: {
                    Image(systemName: "italic")
                }
                .help("斜体")

                Button {
                    commands.apply(.inlineCode)
                } label: {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                }
                .help("行内代码")

                Button {
                    commands.apply(.bullet)
                } label: {
                    Image(systemName: "list.bullet")
                }
                .help("列表")

                Button {
                    commands.apply(.orderedList)
                } label: {
                    Image(systemName: "list.number")
                }
                .help("有序列表")

                Button {
                    commands.apply(.taskList)
                } label: {
                    Image(systemName: "checklist")
                }
                .help("任务列表")

                Button {
                    commands.apply(.quote)
                } label: {
                    Image(systemName: "quote.opening")
                }
                .help("引用")

                Button {
                    commands.apply(.codeBlock)
                } label: {
                    Image(systemName: "curlybraces.square")
                }
                .help("代码块")

                Button {
                    commands.apply(.link)
                } label: {
                    Image(systemName: "link")
                }
                .help("链接")

                Button {
                    commands.apply(.table)
                } label: {
                    Image(systemName: "tablecells")
                }
                .help("表格")
            }
        }
        .buttonStyle(.bordered)
    }
}

private struct MemoRowView: View {
    let memo: MemoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(memo.displayTitle)
                .font(.headline)
                .lineLimit(1)
            Text(memo.previewText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(memo.updatedAt, format: .dateTime.month().day().hour().minute())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#if os(macOS)
private struct MemoCompactRowView: View {
    let memo: MemoEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(memo.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(memo.updatedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
#endif
