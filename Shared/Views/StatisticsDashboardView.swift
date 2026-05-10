import SwiftUI
import SwiftData

struct StatisticsDashboardView: View {
    @Query(sort: [SortDescriptor(\TradeEntry.date, order: .reverse)])
    private var trades: [TradeEntry]
    @State private var period: TradeStatsPeriod = .week
    @State private var selectedChartDate: Date?
    @State private var openedDay: StatDaySelection?
    @State private var openedSymbol: StatSymbolSelection?

    private var summary: TradeStatsSummary {
        TradeAnalytics.summary(for: period, trades: trades)
    }

    private var periodTrades: [TradeEntry] {
        TradeAnalytics.trades(in: period, trades: trades)
    }

    private var dailyPoints: [DailyPnLPoint] {
        TradeAnalytics.dailyPnlSeries(for: period, trades: trades)
    }

    private var symbolRows: [SymbolPnLRow] {
        Array(TradeAnalytics.symbolPnlRows(for: period, trades: trades).prefix(6))
    }

    private var insights: [TradeInsight] {
        TradeAnalytics.insights(for: period, trades: trades)
    }

    private var strategyRows: [TagPerformanceRow] {
        Array(TradeAnalytics.tagPerformanceRows(
            for: period,
            trades: trades,
            keyPath: \.strategyTags
        ).prefix(6))
    }

    private var mistakeRows: [TagPerformanceRow] {
        Array(TradeAnalytics.tagPerformanceRows(
            for: period,
            trades: trades,
            keyPath: \.mistakeTags
        ).prefix(6))
    }

    var body: some View {
        MascotCornerContainer {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    periodPicker
                    StatsCurrencyNotice()
                        .padding(.horizontal)
                    metricGrid
                    pnlDistributionCard

                    InsightSection(insights: insights)
                        .padding(.horizontal)

                    chartGrid
                    tagPerformanceGrid
                }
                .padding(.vertical)
            }
            .background(Color.secondarySystemBackground.opacity(0.45))
        }
        .navigationTitle("统计")
        .toolbar {
            ToolbarItem {
                PetSettingsMenu()
            }
        }
        .sheet(item: $openedDay) { selection in
            NavigationStack {
                TradeDaySummaryView(date: selection.date)
            }
        }
        .sheet(item: $openedSymbol) { selection in
            NavigationStack {
                SymbolTradeListView(
                    ticker: selection.ticker,
                    trades: symbolTrades(for: selection.ticker),
                    amountText: signedMoney,
                    amountColor: pnlColor
                )
            }
        }
    }

    private var periodPicker: some View {
        Picker("周期", selection: $period) {
            ForEach(TradeStatsPeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            StatMetricCard(title: "\(period.rawValue)盈亏", value: signedMoney(summary.pnlTotal), color: pnlColor(summary.pnlTotal), icon: "dollarsign.circle")
            StatMetricCard(title: "胜率", value: percentage(summary.winRate), color: .green, icon: "target")
            StatMetricCard(title: "平均盈亏比", value: signedPercentage(summary.averagePnlPercent / 100), color: pnlColor(summary.averagePnlPercent), icon: "percent")
            StatMetricCard(title: "交易笔数", value: "\(summary.tradeCount)", color: .accentColor, icon: "number.circle")
        }
        .padding(.horizontal)
    }

    private var pnlDistributionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("盈亏分布")
                .font(.headline)
            HStack(spacing: 12) {
                DistributionPill(title: "盈利", value: summary.winningCount, color: .green)
                DistributionPill(title: "亏损", value: summary.losingCount, color: .red)
                DistributionPill(title: "未记录", value: max(summary.tradeCount - summary.winningCount - summary.losingCount, 0), color: .secondary)
            }
        }
        .padding()
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    private var chartGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
            PnLTrendChart(
                points: dailyPoints,
                selectedDate: $selectedChartDate,
                amountText: signedMoney,
                amountColor: pnlColor,
                onOpenDay: openDay
            )
            DailyPnLBarChart(
                points: dailyPoints,
                selectedDate: $selectedChartDate,
                amountText: signedMoney,
                onOpenDay: openDay
            )
            WinRateChart(summary: summary, percentageText: percentage)
            TradeQualityCard(summary: summary, amountText: signedMoney, amountColor: pnlColor)
            SymbolPnLRanking(
                rows: symbolRows,
                amountText: signedMoney,
                amountColor: pnlColor,
                onSelect: { openedSymbol = StatSymbolSelection(ticker: $0.ticker) }
            )
        }
        .padding(.horizontal)
    }

    private var tagPerformanceGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 12)], spacing: 12) {
            TagPerformanceSection(
                title: "策略标签表现",
                emptyText: "还没有策略标签",
                rows: strategyRows,
                amountText: signedMoney,
                amountColor: pnlColor,
                percentageText: percentage
            )
            TagPerformanceSection(
                title: "错误标签表现",
                emptyText: "还没有错误标签",
                rows: mistakeRows,
                amountText: signedMoney,
                amountColor: pnlColor,
                percentageText: percentage
            )
        }
        .padding(.horizontal)
    }

    private func openDay(_ point: DailyPnLPoint) {
        guard point.tradeCount > 0 else { return }
        openedDay = StatDaySelection(date: point.date)
    }

    private func symbolTrades(for ticker: String) -> [TradeEntry] {
        periodTrades.filter {
            $0.ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == ticker
        }
    }

    private func signedMoney(_ value: Double) -> String {
        MoneyFormatters.hkd(value, signed: true)
    }

    private func percentage(_ value: Double) -> String {
        "\(String(format: "%.1f", value * 100))%"
    }

    private func signedPercentage(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value * 100))%"
    }

    private func pnlColor(_ value: Double) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }
}

private struct StatDaySelection: Identifiable {
    let date: Date

    var id: Date { date }
}

private struct StatSymbolSelection: Identifiable {
    let ticker: String

    var id: String { ticker }
}
