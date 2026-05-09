import SwiftUI
import SwiftData

enum MacSidebarItem: String, Hashable, CaseIterable {
    case dashboard = "统计"
    case heatmap = "热力图"
    case trades = "交易"
    case todos = "待办"
    case export = "导出"

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .heatmap: return "calendar.badge.clock"
        case .trades: return "chart.line.uptrend.xyaxis"
        case .todos: return "checkmark.circle"
        case .export: return "square.and.arrow.up"
        }
    }
}

struct MacContentView: View {
    @State private var selectedSidebar: MacSidebarItem? = .dashboard
    @State private var selectedDate: Date = Date()
    @Query(sort: [SortDescriptor(\DiaryEntry.date, order: .reverse)])
    private var allDiaryEntries: [DiaryEntry]

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebar) {
                ForEach(MacSidebarItem.allCases, id: \.self) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                }
            }
            .navigationTitle("StockDiary")
        } content: {
            switch selectedSidebar {
            case .dashboard, .none:
                ContentUnavailableView("统计", systemImage: "chart.bar.xaxis", description: Text("查看本周和本月交易表现"))
                    .navigationTitle("统计")
            case .heatmap:
                CalendarHeatmapView(selectedDate: $selectedDate)
            case .trades:
                TradeListView(selectedDate: $selectedDate)
            case .todos:
                TodoListView(selectedDate: $selectedDate)
            case .export:
                ContentUnavailableView("数据导出", systemImage: "square.and.arrow.up", description: Text("导出 CSV 或 JSON 交易备份"))
                    .navigationTitle("导出")
            }
        } detail: {
            switch selectedSidebar {
            case .dashboard, .none:
                StatisticsDashboardView()
            case .heatmap:
                HeatmapInsightDetailView(date: selectedDate)
                    .id(Calendar.current.startOfDay(for: selectedDate))
            case .trades:
                TradeDaySummaryView(date: selectedDate)
                    .id(Calendar.current.startOfDay(for: selectedDate))
            case .todos:
                TodoDayDetailView(date: selectedDate)
                    .id(Calendar.current.startOfDay(for: selectedDate))
            case .export:
                DataExportView()
            }
        }
    }
}

// MARK: - Trade List

struct TradeListView: View {
    @Binding var selectedDate: Date
    @Query(sort: [SortDescriptor(\TradeEntry.date, order: .reverse)])
    private var trades: [TradeEntry]
    @State private var searchText = ""
    @Environment(\.modelContext) private var modelContext

    private var filteredTrades: [TradeEntry] {
        trades.filter { $0.matchesSearch(searchText) }
    }

    var body: some View {
        List {
            ForEach(filteredTrades) { trade in
                TradeCardView(trade: trade)
                    .onTapGesture {
                        selectedDate = trade.date
                    }
            }
            .onDelete(perform: deleteTrades)

            if !searchText.isEmpty && filteredTrades.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "搜索股票代码、理由、标签...")
        .navigationTitle("交易")
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
