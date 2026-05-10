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
                    amountText: MoneyFormatters.hkdSigned,
                    amountColor: Color.pnl
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
            MetricCard(title: "\(period.rawValue)盈亏", value: MoneyFormatters.hkdSigned(summary.pnlTotal), icon: "dollarsign.circle", color: Color.pnl(summary.pnlTotal), headerStyle: true)
            MetricCard(title: "胜率", value: MoneyFormatters.percentage(summary.winRate), icon: "target", color: .green, headerStyle: true)
            MetricCard(title: "平均盈亏比", value: MoneyFormatters.signedPercentage(summary.averagePnlPercent / 100), icon: "percent", color: Color.pnl(summary.averagePnlPercent), headerStyle: true)
            MetricCard(title: "交易笔数", value: "\(summary.tradeCount)", icon: "number.circle", color: .accentColor, headerStyle: true)
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
                amountText: MoneyFormatters.hkdSigned,
                amountColor: Color.pnl,
                onOpenDay: openDay
            )
            DailyPnLBarChart(
                points: dailyPoints,
                selectedDate: $selectedChartDate,
                amountText: MoneyFormatters.hkdSigned,
                onOpenDay: openDay
            )
            WinRateChart(summary: summary, percentageText: MoneyFormatters.percentage)
            TradeQualityCard(summary: summary, amountText: MoneyFormatters.hkdSigned, amountColor: Color.pnl)
            SymbolPnLRanking(
                rows: symbolRows,
                amountText: MoneyFormatters.hkdSigned,
                amountColor: Color.pnl,
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
                amountText: MoneyFormatters.hkdSigned,
                amountColor: Color.pnl,
                percentageText: MoneyFormatters.percentage
            )
            TagPerformanceSection(
                title: "错误标签表现",
                emptyText: "还没有错误标签",
                rows: mistakeRows,
                amountText: MoneyFormatters.hkdSigned,
                amountColor: Color.pnl,
                percentageText: MoneyFormatters.percentage
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
}

private struct StatDaySelection: Identifiable {
    let date: Date

    var id: Date { date }
}

private struct StatSymbolSelection: Identifiable {
    let ticker: String

    var id: String { ticker }
}
