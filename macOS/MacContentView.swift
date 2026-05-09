import SwiftUI
import SwiftData

enum MacSidebarItem: String, Hashable, CaseIterable {
    case calendar = "日历"
    case trades = "交易"
    case todos = "待办"

    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .trades: return "chart.line.uptrend.xyaxis"
        case .todos: return "checkmark.circle"
        }
    }
}

struct MacContentView: View {
    @State private var selectedSidebar: MacSidebarItem? = .calendar
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
            case .calendar, .none:
                CalendarListView(selectedDate: $selectedDate)
            case .trades:
                TradeListView(selectedDate: $selectedDate)
            case .todos:
                TodoListView(selectedDate: $selectedDate)
            }
        } detail: {
            DayDetailView(date: selectedDate)
                .id(Calendar.current.startOfDay(for: selectedDate))
        }
    }
}

// MARK: - Calendar List

struct CalendarListView: View {
    @Binding var selectedDate: Date
    @Query(sort: [SortDescriptor(\DiaryEntry.date, order: .reverse)])
    private var entries: [DiaryEntry]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List(selection: Binding(
            get: { Calendar.current.startOfDay(for: selectedDate) },
            set: { if let d = $0 { selectedDate = d } }
        )) {
            DatePicker("跳转日期", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(.bottom, 8)

            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if let mood = entry.mood { Text(mood) }
                        Text(DateFormatters.dayDisplay.string(from: entry.date))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    if !entry.content.isEmpty {
                        Text(entry.content)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(Calendar.current.startOfDay(for: entry.date))
            }
            .onDelete(perform: deleteEntries)
        }
        .navigationTitle("日历")
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }
}

// MARK: - Trade List

struct TradeListView: View {
    @Binding var selectedDate: Date
    @Query(sort: [SortDescriptor(\TradeEntry.date, order: .reverse)])
    private var trades: [TradeEntry]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            ForEach(trades) { trade in
                TradeCardView(trade: trade)
                    .onTapGesture {
                        selectedDate = trade.date
                    }
            }
            .onDelete(perform: deleteTrades)
        }
        .navigationTitle("交易")
    }

    private func deleteTrades(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(trades[index])
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
