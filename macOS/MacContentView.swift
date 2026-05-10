import SwiftUI
import SwiftData

enum MacSidebarItem: String, Hashable, CaseIterable {
    case home = "主页"
    case dashboard = "统计"
    case heatmap = "概览"
    case trades = "交易"
    case watchlist = "自选"
    case positions = "持仓"
    case memos = "随记"
    case todos = "待办"
    case export = "导出"
    case settings = "设置"

    var icon: String {
        switch self {
        case .home: return "house"
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .heatmap: return "calendar.badge.clock"
        case .trades: return "chart.line.uptrend.xyaxis"
        case .watchlist: return "star"
        case .positions: return "briefcase"
        case .memos: return "square.and.pencil"
        case .todos: return "checkmark.circle"
        case .export: return "square.and.arrow.up"
        case .settings: return "gearshape"
        }
    }
}

struct MacContentView: View {
    @State private var selectedSidebar: MacSidebarItem? = .home
    @State private var selectedDate: Date = Date()

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebar) {
                ForEach(MacSidebarItem.allCases, id: \.self) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                }
            }
            .navigationTitle("StockDiary")
        } detail: {
            switch selectedSidebar {
            case .home, .none:
                HomeDashboardView()
            case .dashboard:
                StatisticsDashboardView()
            case .heatmap:
                CalendarHeatmapView(selectedDate: $selectedDate)
            case .trades:
                TradeListView(selectedDate: $selectedDate)
            case .watchlist:
                WatchlistView()
            case .positions:
                IBKRPositionsView()
            case .memos:
                MemoRootView()
            case .todos:
                MacTodoBoardView(selectedDate: $selectedDate)
            case .export:
                MascotCornerContainer {
                    DataExportView()
                }
            case .settings:
                MascotCornerContainer {
                    MacSettingsView()
                }
            }
        }
    }
}

// MARK: - Mac Todo Board

struct MacTodoBoardView: View {
    @Binding var selectedDate: Date

    var body: some View {
        MascotCornerContainer {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("待办")
                                .font(.largeTitle)
                                .fontWeight(.semibold)
                            Text(DateFormatters.dayDisplay.string(from: selectedDate))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        DatePicker("日期", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }

                    TodoDayDetailView(date: selectedDate)
                        .id(Calendar.current.startOfDay(for: selectedDate))
                }
                .padding()
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color.secondarySystemBackground.opacity(0.45))
        }
        .navigationTitle("待办")
    }
}

// MARK: - Mac Settings

struct MacSettingsView: View {
    @Environment(IBKRSyncManager.self) private var syncManager

    var body: some View {
        Form {
            IBKRSettingsView(syncManager: syncManager)
            ExchangeRateSettingsView()

            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
    }
}

// MARK: - Trade List

struct TradeListView: View {
    @Binding var selectedDate: Date
    @Query(sort: [SortDescriptor(\TradeEntry.date, order: .reverse)])
    private var trades: [TradeEntry]
    @State private var searchText = ""
    @State private var showSyncAlert = false
    @State private var selectedTradeId: UUID?
    @Environment(\.modelContext) private var modelContext
    @Environment(IBKRSyncManager.self) private var syncManager

    private var filteredTrades: [TradeEntry] {
        trades.filter { $0.matchesSearch(searchText) }
    }

    var body: some View {
        List(selection: $selectedTradeId) {
            ForEach(filteredTrades) { trade in
                TradeCardView(trade: trade)
                    .tag(trade.id)
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation {
                                modelContext.delete(trade)
                                try? modelContext.save()
                            }
                        } label: {
                            Label("删除交易", systemImage: "trash")
                        }
                    }
            }
            .onDelete { offsets in
                withAnimation {
                    for index in offsets {
                        modelContext.delete(filteredTrades[index])
                    }
                    try? modelContext.save()
                }
            }

            if !searchText.isEmpty && filteredTrades.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "搜索股票代码、理由、标签...")
        .navigationTitle("交易")
        .toolbar {
            ToolbarItem {
                Button {
                    Task {
                        await syncManager.manualSync(context: modelContext)
                        showSyncAlert = true
                    }
                } label: {
                    if syncManager.isSyncing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(syncManager.isSyncing)
            }
            ToolbarItem {
                Button {
                    let trade = TradeEntry(date: Calendar.current.startOfDay(for: selectedDate))
                    modelContext.insert(trade)
                    selectedDate = trade.date
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("IBKR 同步", isPresented: $showSyncAlert) {
            Button("好") {}
        } message: {
            Text(syncManager.lastSyncResult?.message ?? "同步完成")
        }
        .onChange(of: selectedTradeId) { _, newId in
            if let newId, let trade = filteredTrades.first(where: { $0.id == newId }) {
                selectedDate = trade.date
            }
        }
        .onDeleteCommand {
            if let selectedTradeId,
               let trade = filteredTrades.first(where: { $0.id == selectedTradeId }) {
                withAnimation {
                    modelContext.delete(trade)
                    try? modelContext.save()
                    self.selectedTradeId = nil
                }
            }
        }
    }

    private func deleteTrades(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredTrades[index])
        }
    }
}

// MARK: - Todo List

struct TodoListView: View {
    @Binding var selectedDate: Date
    @Query(sort: [SortDescriptor(\TodoItem.date, order: .reverse)])
    private var todos: [TodoItem]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            ForEach(todos) { todo in
                HStack {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(todo.isCompleted ? .green : .secondary)
                        .onTapGesture { todo.isCompleted.toggle() }
                    VStack(alignment: .leading) {
                        Text(todo.title)
                            .strikethrough(todo.isCompleted)
                        Text(DateFormatters.shortDate.string(from: todo.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onTapGesture { selectedDate = todo.date }
            }
            .onDelete(perform: deleteTodos)
        }
        .navigationTitle("待办")
    }

    private func deleteTodos(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(todos[index])
        }
    }
}
