import SwiftUI
import SwiftData

struct HeatmapInsightDetailView: View {
    let date: Date
    @Query private var trades: [TradeEntry]
    @Query private var diaries: [DiaryEntry]
    @Query private var todos: [TodoItem]

    private let calendar = Calendar.current

    init(date: Date) {
        self.date = date
        let monthStart = Calendar.current.dateInterval(of: .month, for: date)?.start ?? Calendar.current.startOfDay(for: date)
        let monthEnd = Calendar.current.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        _trades = Query(
            filter: #Predicate<TradeEntry> { trade in
                trade.date >= monthStart && trade.date < monthEnd
            },
            sort: [SortDescriptor(\.date)]
        )
        _diaries = Query(
            filter: #Predicate<DiaryEntry> { entry in
                entry.date >= monthStart && entry.date < monthEnd
            },
            sort: [SortDescriptor(\.date)]
        )
        _todos = Query(
            filter: #Predicate<TodoItem> { todo in
                todo.date >= monthStart && todo.date < monthEnd
            },
            sort: [SortDescriptor(\.date)]
        )
    }

    private var summaries: [DailyRecordSummary] {
        TradeAnalytics.dailySummaries(trades: trades, diaries: diaries, todos: todos)
            .values
            .sorted { $0.date < $1.date }
    }

    private var selectedSummary: DailyRecordSummary? {
        summaries.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var activeDays: Int {
        summaries.filter(\.hasRecord).count
    }

    private var tradeDays: [DailyRecordSummary] {
        summaries.filter { $0.tradeCount > 0 }
    }

    private var bestDay: DailyRecordSummary? {
        tradeDays.max { $0.pnlTotal < $1.pnlTotal }
    }

    private var worstDay: DailyRecordSummary? {
        tradeDays.min { $0.pnlTotal < $1.pnlTotal }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(DateFormatters.dayDisplay.string(from: date))
                    .font(.title2)
                    .fontWeight(.semibold)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                    SummaryMetricTile(title: "当日交易", value: "\(selectedSummary?.tradeCount ?? 0)", icon: "chart.line.uptrend.xyaxis", color: .accentColor)
                    SummaryMetricTile(title: "当日盈亏", value: money(selectedSummary?.pnlTotal ?? 0), icon: "dollarsign.circle", color: pnlColor(selectedSummary?.pnlTotal ?? 0))
                    SummaryMetricTile(title: "本月活跃日", value: "\(activeDays)", icon: "calendar", color: .blue)
                    SummaryMetricTile(title: "本月交易日", value: "\(tradeDays.count)", icon: "target", color: .purple)
                }

                PnLRangeView(bestDay: bestDay, worstDay: worstDay)

                VStack(alignment: .leading, spacing: 10) {
                    Text("本月日度表现")
                        .font(.headline)
                    if tradeDays.isEmpty {
                        Text("本月还没有交易记录")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(tradeDays) { summary in
                            DailyPnLBar(summary: summary)
                        }
                    }
                }
                .padding()
                .background(Color.systemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding()
        }
        .background(Color.secondarySystemBackground.opacity(0.45))
        .navigationTitle("热力分析")
    }

    private func money(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)$\(String(format: "%.2f", value))"
    }

    private func pnlColor(_ value: Double) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }
}

struct TradeDaySummaryView: View {
    let date: Date
    @Query private var trades: [TradeEntry]

    init(date: Date) {
        self.date = date
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _trades = Query(
            filter: #Predicate<TradeEntry> { trade in
                trade.date >= start && trade.date < end
            },
            sort: [SortDescriptor(\.createdAt)]
        )
    }

    private var pnlTotal: Double {
        trades.compactMap(\.pnl).reduce(0, +)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(DateFormatters.dayDisplay.string(from: date))
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    SummaryMetricTile(title: "交易笔数", value: "\(trades.count)", icon: "number.circle", color: .accentColor)
                    SummaryMetricTile(title: "当日盈亏", value: money(pnlTotal), icon: "dollarsign.circle", color: pnlColor(pnlTotal))
                }

                if trades.isEmpty {
                    ContentUnavailableView("没有交易", systemImage: "chart.line.uptrend.xyaxis", description: Text("从左侧选择有交易记录的日期"))
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    ForEach(trades) { trade in
                        TradeCardView(trade: trade)
                    }
                }
            }
            .padding()
        }
        .background(Color.secondarySystemBackground.opacity(0.45))
        .navigationTitle("交易摘要")
    }

    private func money(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)$\(String(format: "%.2f", value))"
    }

    private func pnlColor(_ value: Double) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }
}

struct TodoDayDetailView: View {
    let date: Date
    @Environment(\.modelContext) private var modelContext
    @State private var diaryEntry: DiaryEntry?
    @State private var isShowingStatus = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DateFormatters.dayDisplay.string(from: date))
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("待办和当日状态")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    loadOrCreateDiary()
                    isShowingStatus = true
                } label: {
                    Label("今日状态", systemImage: "slider.horizontal.3")
                }
            }

            TodoEditorView(date: date)

            Spacer()
        }
        .padding()
        .navigationTitle("待办详情")
        .popover(isPresented: $isShowingStatus, arrowEdge: .top) {
            if let diaryEntry {
                DiaryEditorView(entry: diaryEntry)
                    .frame(minWidth: 420, minHeight: 520)
            }
        }
        .onDisappear {
            cleanupEmptyDiary()
        }
    }

    private func loadOrCreateDiary() {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let predicate = #Predicate<DiaryEntry> { entry in
            entry.date >= dayStart && entry.date < dayEnd
        }
        let descriptor = FetchDescriptor<DiaryEntry>(predicate: predicate)
        if let existing = try? modelContext.fetch(descriptor).first {
            diaryEntry = existing
        } else {
            let newEntry = DiaryEntry(date: dayStart)
            modelContext.insert(newEntry)
            diaryEntry = newEntry
        }
    }

    private func cleanupEmptyDiary() {
        guard let diaryEntry, diaryEntry.isEmpty else { return }
        modelContext.delete(diaryEntry)
        self.diaryEntry = nil
    }
}

struct SearchDetailPlaceholderView: View {
    let date: Date

    var body: some View {
        ContentUnavailableView(
            "搜索结果",
            systemImage: "magnifyingglass",
            description: Text("选择左侧结果后会切换到对应日期")
        )
        .navigationTitle(DateFormatters.dayDisplay.string(from: date))
    }
}

private struct SummaryMetricTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PnLRangeView: View {
    let bestDay: DailyRecordSummary?
    let worstDay: DailyRecordSummary?

    var body: some View {
        HStack(spacing: 12) {
            RangeCard(title: "最佳日", summary: bestDay, color: .green)
            RangeCard(title: "回撤日", summary: worstDay, color: .red)
        }
    }
}

private struct RangeCard: View {
    let title: String
    let summary: DailyRecordSummary?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let summary {
                Text(DateFormatters.shortDate.string(from: summary.date))
                    .font(.headline)
                Text(money(summary.pnlTotal))
                    .font(.subheadline)
                    .foregroundStyle(color)
                    .monospacedDigit()
            } else {
                Text("-")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func money(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)$\(String(format: "%.2f", value))"
    }
}

private struct DailyPnLBar: View {
    let summary: DailyRecordSummary

    private var color: Color {
        if summary.pnlTotal > 0 { return .green }
        if summary.pnlTotal < 0 { return .red }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(DateFormatters.shortDate.string(from: summary.date))
                .font(.caption)
                .frame(width: 38, alignment: .leading)
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.75))
                    .frame(width: max(proxy.size.width * min(abs(summary.pnlTotal) / 500, 1), 4))
            }
            .frame(height: 8)
            Text(money(summary.pnlTotal))
                .font(.caption)
                .foregroundStyle(color)
                .monospacedDigit()
                .frame(width: 74, alignment: .trailing)
        }
    }

    private func money(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)$\(String(format: "%.2f", value))"
    }
}
