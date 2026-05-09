import SwiftUI
import SwiftData

struct HomeDashboardView: View {
    @Query(sort: [
        SortDescriptor(\TradeEntry.date, order: .reverse),
        SortDescriptor(\TradeEntry.createdAt, order: .reverse)
    ])
    private var trades: [TradeEntry]
    @Query(sort: [
        SortDescriptor(\TodoItem.date, order: .reverse),
        SortDescriptor(\TodoItem.createdAt, order: .reverse)
    ])
    private var todos: [TodoItem]

    private var recentTrades: ArraySlice<TradeEntry> {
        trades.prefix(3)
    }

    private var recentTodos: ArraySlice<TodoItem> {
        todos.prefix(3)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PetCompanionView()

                HomeSectionHeader(title: "最近三笔交易", icon: "chart.line.uptrend.xyaxis")

                if recentTrades.isEmpty {
                    HomeEmptyRow(icon: "chart.line.uptrend.xyaxis", text: "还没有交易记录")
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(recentTrades)) { trade in
                            TradeCardView(trade: trade)
                        }
                    }
                }

                HomeSectionHeader(title: "最近三项待办", icon: "checkmark.circle")

                if recentTodos.isEmpty {
                    HomeEmptyRow(icon: "checkmark.circle", text: "还没有待办")
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(recentTodos)) { todo in
                            HomeTodoRow(todo: todo)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.secondarySystemBackground.opacity(0.45))
        .navigationTitle("主页")
    }
}

private struct HomeSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.top, 4)
    }
}

private struct HomeTodoRow: View {
    let todo: TodoItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(todo.isCompleted ? .green : .secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .font(.subheadline)
                    .strikethrough(todo.isCompleted)
                Text(DateFormatters.shortDate.string(from: todo.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct HomeEmptyRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
