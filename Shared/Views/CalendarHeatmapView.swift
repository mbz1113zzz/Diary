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
    private let columns = Array(repeating: GridItem(.fixed(38), spacing: 8), count: 7)
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

    private var visibleMonthInterval: DateInterval? {
        calendar.dateInterval(of: .month, for: visibleMonth)
    }

    private var monthSummaries: [DailyRecordSummary] {
        guard let visibleMonthInterval else { return [] }
        return summaries.values
            .filter { visibleMonthInterval.contains($0.date) }
            .sorted { $0.date < $1.date }
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
            VStack(alignment: .leading, spacing: 0) {
                monthPanel
            }
            .padding(.vertical)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.secondarySystemBackground.opacity(0.45))
        .navigationTitle("概览")
    }

    private var monthPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Month navigation
            HStack(spacing: 12) {
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

            // Legend
            HStack(spacing: 12) {
                LegendItem(color: .green, text: "盈利")
                LegendItem(color: .red, text: "亏损")
                LegendItem(color: .gray, text: "无交易")
                Spacer()
            }

            // Stats: horizontal row of 3 pills
            HStack(spacing: 12) {
                HeatmapOverviewPill(title: "活跃日", value: "\(activeDays)", color: .blue, icon: "calendar")
                HeatmapOverviewPill(title: "交易数", value: "\(monthlyTradeCount)", color: .accentColor, icon: "number.circle")
                HeatmapOverviewPill(title: "月盈亏", value: signedMoney(monthlyPnl), color: pnlColor(monthlyPnl), icon: "dollarsign.circle")
            }

            // Calendar centered
            calendarGrid
                .frame(maxWidth: .infinity, alignment: .center)

            Divider()
                .padding(.vertical, 4)

            // Selected day detail integrated in the same panel
            selectedDayDetail
        }
        .padding(18)
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
        .padding(.horizontal)
    }

    private var calendarGrid: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption)
                        .fontWeight(.medium)
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
        }
        .frame(width: 322)
    }

    private var selectedDayDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func moveMonth(by value: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
    }

    private func signedMoney(_ value: Double) -> String {
        MoneyFormatters.hkd(value, signed: true)
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
            return Color.clear
        }
        guard summary.tradeCount > 0 else {
            return .gray.opacity(0.35)
        }
        if summary.pnlTotal > 0 { return .green.opacity(0.75) }
        if summary.pnlTotal < 0 { return .red.opacity(0.75) }
        return .gray.opacity(0.35)
    }

    private var hasRecord: Bool {
        summary?.hasRecord == true
    }

    private var foregroundColor: Color {
        hasRecord && (summary?.tradeCount ?? 0) > 0 ? .white : .primary
    }

    var body: some View {
        ZStack {
            if hasRecord {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 24, height: 24)
            }

            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(foregroundColor)

            if isSelected {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: 28, height: 28)
            }
        }
        .frame(width: 38, height: 38)
        .contentShape(Rectangle())
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
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondarySystemBackground.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.08), lineWidth: 1)
        }
    }
}
