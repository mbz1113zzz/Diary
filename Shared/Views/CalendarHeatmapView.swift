import SwiftUI
import SwiftData

struct CalendarHeatmapView: View {
    @Binding var selectedDate: Date
    @Query(sort: [SortDescriptor(\TradeEntry.date)])
    private var trades: [TradeEntry]
    @Query(sort: [SortDescriptor(\DiaryEntry.date)])
    private var diaries: [DiaryEntry]
    @Query(sort: [SortDescriptor(\TodoItem.date)])
    private var todos: [TodoItem]
    @State private var visibleMonth: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

    init(selectedDate: Binding<Date>) {
        _selectedDate = selectedDate
        _visibleMonth = State(initialValue: Calendar.current.dateInterval(of: .month, for: selectedDate.wrappedValue)?.start ?? Date())
    }

    private var summaries: [Date: DailyRecordSummary] {
        TradeAnalytics.dailySummaries(trades: trades, diaries: diaries, todos: todos)
    }

    private var cells: [HeatmapCell] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: visibleMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingSpaces = (firstWeekday + 5) % 7
        var cells = (0..<leadingSpaces).map { HeatmapCell(id: "blank-\($0)", date: nil) }

        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                cells.append(HeatmapCell(id: DateFormatters.exportDate.string(from: date), date: date))
            }
        }

        return cells
    }

    private var selectedSummary: DailyRecordSummary? {
        summaries[calendar.startOfDay(for: selectedDate)]
    }

    private var monthSummaries: [DailyRecordSummary] {
        summaries.values.sorted { $0.date < $1.date }
    }

    private var activeDays: Int {
        monthSummaries.filter(\.hasRecord).count
    }

    private var monthlyTradeCount: Int {
        monthSummaries.reduce(0) { $0 + $1.tradeCount }
    }

    private var monthlyPnl: Double {
        monthSummaries.reduce(0) { $0 + $1.pnlTotal }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button {
                        moveMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)

                    Spacer()

                    Text(DateFormatters.monthTitle.string(from: visibleMonth))
                        .font(.headline)

                    Spacer()

                    Button {
                        moveMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal)

                HStack {
                    LegendItem(color: .green, text: "盈利")
                    LegendItem(color: .red, text: "亏损")
                    LegendItem(color: .gray, text: "无交易")
                }
                .padding(.horizontal)

                HStack(spacing: 8) {
                    HeatmapOverviewPill(title: "活跃日", value: "\(activeDays)", color: .blue)
                    HeatmapOverviewPill(title: "交易数", value: "\(monthlyTradeCount)", color: .accentColor)
                    HeatmapOverviewPill(title: "月盈亏", value: signedMoney(monthlyPnl), color: pnlColor(monthlyPnl))
                }
                .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(weekdays, id: \.self) { weekday in
                        Text(weekday)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(cells) { cell in
                        if let date = cell.date {
                            HeatmapDayCell(
                                date: date,
                                summary: summaries[calendar.startOfDay(for: date)],
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                            )
                            .onTapGesture {
                                selectedDate = date
                            }
                        } else {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text(DateFormatters.dayDisplay.string(from: selectedDate))
                        .font(.headline)
                    if let selectedSummary, selectedSummary.hasRecord {
                        HStack(spacing: 12) {
                            Label("\(selectedSummary.tradeCount)笔交易", systemImage: "chart.line.uptrend.xyaxis")
                            Label("\(selectedSummary.diaryCount)篇日记", systemImage: "book")
                            Label("\(selectedSummary.todoCount)个待办", systemImage: "checkmark.circle")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text("当日盈亏 \(signedMoney(selectedSummary.pnlTotal))")
                            .font(.subheadline)
                            .foregroundStyle(pnlColor(selectedSummary.pnlTotal))
                            .monospacedDigit()
                    } else {
                        Text("这一天还没有记录")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.systemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.secondarySystemBackground.opacity(0.45))
        .navigationTitle("热力图")
    }

    private func moveMonth(by value: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
    }

    private func signedMoney(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)$\(String(format: "%.2f", value))"
    }

    private func pnlColor(_ value: Double) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }
}

private struct HeatmapCell: Identifiable {
    let id: String
    let date: Date?
}

private struct HeatmapDayCell: View {
    let date: Date
    let summary: DailyRecordSummary?
    let isSelected: Bool

    private var backgroundColor: Color {
        guard let summary, summary.hasRecord else {
            return Color.secondarySystemBackground
        }
        guard summary.tradeCount > 0 else {
            return .gray.opacity(0.35)
        }
        if summary.pnlTotal > 0 { return .green.opacity(0.75) }
        if summary.pnlTotal < 0 { return .red.opacity(0.75) }
        return .gray.opacity(0.35)
    }

    var body: some View {
        Text("\(Calendar.current.component(.day, from: date))")
            .font(.caption)
            .fontWeight(isSelected ? .bold : .regular)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(backgroundColor)
            .foregroundStyle((summary?.tradeCount ?? 0) > 0 ? Color.white : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor, lineWidth: 2)
                }
            }
    }
}

private struct LegendItem: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct HeatmapOverviewPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
