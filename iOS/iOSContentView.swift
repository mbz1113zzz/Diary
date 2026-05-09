import SwiftUI
import SwiftData

struct iOSContentView: View {
    @State private var showingNewEntrySheet = false
    @State private var newEntryType: NewEntryType?

    enum NewEntryType: Identifiable {
        case diary, trade
        var id: Self { self }
    }

    var body: some View {
        TabView {
            DiaryTabView()
                .tabItem {
                    Label("日记", systemImage: "book")
                }

            TradeTabView()
                .tabItem {
                    Label("交易", systemImage: "chart.line.uptrend.xyaxis")
                }

            Text("")
                .tabItem {
                    Label("新建", systemImage: "plus.circle.fill")
                }

            TodoTabView()
                .tabItem {
                    Label("待办", systemImage: "checkmark.circle")
                }

            SettingsTabView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .overlay(alignment: .bottom) {
            NewEntryButton { type in
                newEntryType = type
            }
            .offset(y: -28)
        }
        .sheet(item: $newEntryType) { type in
            NavigationStack {
                switch type {
                case .diary:
                    NewDiarySheetView()
                case .trade:
                    NewTradeSheetView()
                }
            }
        }
    }
}

// MARK: - New Entry Button

struct NewEntryButton: View {
    var onTap: (iOSContentView.NewEntryType) -> Void

    var body: some View {
        Menu {
            Button {
                onTap(.diary)
            } label: {
                Label("新建日记", systemImage: "book")
            }
            Button {
                onTap(.trade)
            } label: {
                Label("新建交易", systemImage: "chart.line.uptrend.xyaxis")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white, .accentColor)
                .shadow(radius: 4)
        }
    }
}

// MARK: - Diary Tab

struct DiaryTabView: View {
    @Query(sort: [SortDescriptor(\DiaryEntry.date, order: .reverse)])
    private var entries: [DiaryEntry]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    NavigationLink {
                        DayDetailView(date: entry.date)
                    } label: {
                        DiaryCardView(entry: entry)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .onDelete(perform: deleteEntries)
            }
            .listStyle(.plain)
            .overlay {
                if entries.isEmpty {
                    EmptyStateView(
                        icon: "book",
                        title: "还没有日记",
                        subtitle: "点击下方 + 按钮开始记录"
                    )
                }
            }
            .navigationTitle("日记")
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }
}

// MARK: - Trade Tab

struct TradeTabView: View {
    @Query(sort: [SortDescriptor(\TradeEntry.date, order: .reverse)])
    private var trades: [TradeEntry]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(trades) { trade in
                    NavigationLink {
                        TradeEditorView(trade: trade)
                            .navigationTitle(trade.ticker)
                    } label: {
                        TradeCardView(trade: trade)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .onDelete(perform: deleteTrades)
            }
            .listStyle(.plain)
            .overlay {
                if trades.isEmpty {
                    EmptyStateView(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "还没有交易记录",
                        subtitle: "点击下方 + 按钮记录你的第一笔交易"
                    )
                }
            }
            .navigationTitle("交易")
        }
    }

    private func deleteTrades(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(trades[index])
        }
    }
}

// MARK: - Todo Tab

struct TodoTabView: View {
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("日期", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(.horizontal)
                TodoEditorView(date: selectedDate)
                    .padding()
                Spacer()
            }
            .navigationTitle("待办")
        }
    }
}

// MARK: - Settings Tab

struct SettingsTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("数据") {
                    HStack {
                        Text("iCloud 同步")
                        Spacer()
                        Text("未启用")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}

// MARK: - New Entry Sheets

struct NewDiarySheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var entry: DiaryEntry?

    var body: some View {
        Group {
            if let entry {
                DiaryEditorView(entry: entry)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("新建日记")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    if let entry { modelContext.delete(entry) }
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { dismiss() }
            }
        }
        .onAppear {
            let newEntry = DiaryEntry(date: Calendar.current.startOfDay(for: Date()))
            modelContext.insert(newEntry)
            entry = newEntry
        }
    }
}

struct NewTradeSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var trade: TradeEntry?

    var body: some View {
        Group {
            if let trade {
                TradeEditorView(trade: trade)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("新建交易")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    if let trade { modelContext.delete(trade) }
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { dismiss() }
            }
        }
        .onAppear {
            let newTrade = TradeEntry(date: Calendar.current.startOfDay(for: Date()))
            modelContext.insert(newTrade)
            trade = newTrade
        }
    }
}
