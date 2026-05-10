import SwiftUI
import SwiftData
import Charts

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
                    Picker("周期", selection: $period) {
                        ForEach(TradeStatsPeriod.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    StatsCurrencyNotice()
                        .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        StatMetricCard(title: "\(period.rawValue)盈亏", value: signedMoney(summary.pnlTotal), color: pnlColor(summary.pnlTotal), icon: "dollarsign.circle")
                        StatMetricCard(title: "胜率", value: percentage(summary.winRate), color: .green, icon: "target")
                        StatMetricCard(title: "平均盈亏比", value: signedPercentage(summary.averagePnlPercent / 100), color: pnlColor(summary.averagePnlPercent), icon: "percent")
                        StatMetricCard(title: "交易笔数", value: "\(summary.tradeCount)", color: .accentColor, icon: "number.circle")
                    }
                    .padding(.horizontal)

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

                    InsightSection(insights: insights)
                        .padding(.horizontal)

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

private struct InsightSection: View {
    let insights: [TradeInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("自动洞察", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                if !insights.isEmpty {
                    Text("\(insights.count) 条")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if insights.isEmpty {
                Text("交易数据还不够，记录几笔带盈亏的交易后会生成复盘提示。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                    ForEach(insights) { insight in
                        InsightCard(insight: insight)
                    }
                }
            }
        }
        .padding()
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct InsightCard: View {
    let insight: TradeInsight

    private var color: Color {
        switch insight.tone {
        case .positive: return .green
        case .negative: return .red
        case .warning: return .orange
        case .neutral: return .accentColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: insight.icon)
                    .foregroundStyle(color)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text(insight.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(insight.value)
                        .font(.headline)
                        .foregroundStyle(color)
                        .lineLimit(1)
                }
            }

            Text(insight.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct TagPerformanceSection: View {
    let title: String
    let emptyText: String
    let rows: [TagPerformanceRow]
    let amountText: (Double) -> String
    let amountColor: (Double) -> Color
    let percentageText: (Double) -> String

    private var maxMagnitude: Double {
        max(rows.map { abs($0.pnl) }.max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            if rows.isEmpty {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(rows) { row in
                        TagPerformanceRowView(
                            row: row,
                            maxMagnitude: maxMagnitude,
                            amountText: amountText,
                            amountColor: amountColor,
                            percentageText: percentageText
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct TagPerformanceRowView: View {
    let row: TagPerformanceRow
    let maxMagnitude: Double
    let amountText: (Double) -> String
    let amountColor: (Double) -> Color
    let percentageText: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.tag)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(row.tradeCount)笔")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(amountText(row.pnl))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amountColor(row.pnl))
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                    Capsule()
                        .fill(amountColor(row.pnl).opacity(0.72))
                        .frame(width: max(proxy.size.width * abs(row.pnl) / maxMagnitude, 6))
                }
            }
            .frame(height: 8)

            HStack(spacing: 10) {
                TagMiniMetric(title: "胜率", value: percentageText(row.winRate), color: .green)
                TagMiniMetric(title: "均值", value: amountText(row.averagePnl), color: amountColor(row.averagePnl))
                TagMiniMetric(title: "已记录", value: "\(row.recordedCount)笔", color: .secondary)
            }
        }
    }
}

private struct TagMiniMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .font(.caption)
    }
}

private struct StatsCurrencyNotice: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.accentColor)
            Text("统计图表统一按固定汇率折算为 HKD，交易卡片仍保留原币种提示。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatMetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
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

private struct DistributionPill: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PnLTrendChart: View {
    let points: [DailyPnLPoint]
    @Binding var selectedDate: Date?
    let amountText: (Double) -> String
    let amountColor: (Double) -> Color
    let onOpenDay: (DailyPnLPoint) -> Void

    private var latestValue: Double {
        points.last?.cumulativePnl ?? 0
    }

    private var selectedPoint: DailyPnLPoint? {
        nearestPoint(to: selectedDate, in: points)
    }

    private var hasTradeData: Bool {
        points.contains { $0.tradeCount > 0 }
    }

    var body: some View {
        ChartCard(title: "盈亏趋势", subtitle: amountText(latestValue), subtitleColor: amountColor(latestValue)) {
            if !hasTradeData {
                ChartEmptyState(text: "还没有交易数据")
            } else {
                Chart {
                    RuleMark(y: .value("零线", 0))
                        .foregroundStyle(Color.secondary.opacity(0.28))

                    if let selectedPoint {
                        RuleMark(x: .value("选中日期", selectedPoint.date, unit: .day))
                            .foregroundStyle(Color.secondary.opacity(0.32))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }

                    ForEach(points) { point in
                        AreaMark(
                            x: .value("日期", point.date, unit: .day),
                            y: .value("累计盈亏", point.cumulativePnl)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [amountColor(latestValue).opacity(0.28), amountColor(latestValue).opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("日期", point.date, unit: .day),
                            y: .value("累计盈亏", point.cumulativePnl)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(amountColor(latestValue))
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }

                    if let selectedPoint {
                        PointMark(
                            x: .value("选中日期", selectedPoint.date, unit: .day),
                            y: .value("累计盈亏", selectedPoint.cumulativePnl)
                        )
                        .symbolSize(80)
                        .foregroundStyle(amountColor(selectedPoint.cumulativePnl))
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.secondary.opacity(0.12))
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.secondary.opacity(0.12))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(compactMoney(amount))
                            }
                        }
                    }
                }
                .frame(height: 210)

                if let selectedPoint {
                    ChartPointCallout(
                        title: DateFormatters.dayDisplay.string(from: selectedPoint.date),
                        primaryText: amountText(selectedPoint.cumulativePnl),
                        primaryLabel: "累计盈亏",
                        secondaryText: "\(selectedPoint.tradeCount) 笔",
                        secondaryLabel: "当日交易",
                        color: amountColor(selectedPoint.cumulativePnl),
                        canOpen: selectedPoint.tradeCount > 0,
                        onOpen: { onOpenDay(selectedPoint) }
                    )
                }
            }
        }
    }
}

private struct DailyPnLBarChart: View {
    let points: [DailyPnLPoint]
    @Binding var selectedDate: Date?
    let amountText: (Double) -> String
    let onOpenDay: (DailyPnLPoint) -> Void

    private var totalTrades: Int {
        points.reduce(0) { $0 + $1.tradeCount }
    }

    private var selectedPoint: DailyPnLPoint? {
        nearestPoint(to: selectedDate, in: points)
    }

    var body: some View {
        ChartCard(title: "每日盈亏", subtitle: "\(totalTrades) 笔交易", subtitleColor: .secondary) {
            if totalTrades == 0 {
                ChartEmptyState(text: "还没有每日盈亏")
            } else {
                Chart {
                    RuleMark(y: .value("零线", 0))
                        .foregroundStyle(Color.secondary.opacity(0.28))

                    if let selectedPoint {
                        RuleMark(x: .value("选中日期", selectedPoint.date, unit: .day))
                            .foregroundStyle(Color.secondary.opacity(0.32))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }

                    ForEach(points) { point in
                        BarMark(
                            x: .value("日期", point.date, unit: .day),
                            y: .value("盈亏", point.pnl)
                        )
                        .foregroundStyle(barColor(for: point.pnl))
                        .cornerRadius(4)
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine()
                            .foregroundStyle(Color.secondary.opacity(0.12))
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.secondary.opacity(0.12))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(compactMoney(amount))
                            }
                        }
                    }
                }
                .frame(height: 210)

                if let selectedPoint {
                    ChartPointCallout(
                        title: DateFormatters.dayDisplay.string(from: selectedPoint.date),
                        primaryText: amountText(selectedPoint.pnl),
                        primaryLabel: "当日盈亏",
                        secondaryText: "\(selectedPoint.tradeCount) 笔",
                        secondaryLabel: "当日交易",
                        color: barColor(for: selectedPoint.pnl),
                        canOpen: selectedPoint.tradeCount > 0,
                        onOpen: { onOpenDay(selectedPoint) }
                    )
                }
            }
        }
    }

    private func barColor(for value: Double) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary.opacity(0.35)
    }
}

private struct WinRateChart: View {
    let summary: TradeStatsSummary
    let percentageText: (Double) -> String

    private var recordedCount: Int {
        summary.winningCount + summary.losingCount
    }

    var body: some View {
        ChartCard(title: "胜率结构", subtitle: "\(recordedCount) 笔已记录盈亏", subtitleColor: .secondary) {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.16), lineWidth: 16)

                    Circle()
                        .trim(from: 0, to: min(max(summary.winRate, 0), 1))
                        .stroke(.green, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Text(percentageText(summary.winRate))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("胜率")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 150, height: 150)

                HStack(spacing: 10) {
                    DistributionPill(title: "盈利", value: summary.winningCount, color: .green)
                    DistributionPill(title: "亏损", value: summary.losingCount, color: .red)
                    DistributionPill(title: "未记录", value: max(summary.tradeCount - recordedCount, 0), color: .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 210)
        }
    }
}

private struct TradeQualityCard: View {
    let summary: TradeStatsSummary
    let amountText: (Double) -> String
    let amountColor: (Double) -> Color

    var body: some View {
        ChartCard(
            title: "盈亏质量",
            subtitle: summary.payoffRatio > 0 ? "\(String(format: "%.2f", summary.payoffRatio))R" : "暂无比值",
            subtitleColor: summary.payoffRatio >= 1 ? .green : .orange
        ) {
            VStack(alignment: .leading, spacing: 18) {
                QualityMetricRow(
                    title: "平均盈利",
                    value: amountText(summary.averageWin),
                    detail: "\(summary.winningCount) 笔盈利交易",
                    color: amountColor(summary.averageWin)
                )
                QualityMetricRow(
                    title: "平均亏损",
                    value: amountText(summary.averageLoss),
                    detail: "\(summary.losingCount) 笔亏损交易",
                    color: amountColor(summary.averageLoss)
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("盈亏比")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(summary.payoffRatio > 0 ? "\(String(format: "%.2f", summary.payoffRatio)) : 1" : "暂无")
                            .font(.headline)
                            .monospacedDigit()
                    }

                    GeometryReader { proxy in
                        HStack(spacing: 4) {
                            Capsule()
                                .fill(Color.green.opacity(0.72))
                                .frame(width: qualityBarWidth(proxy.size.width, value: summary.averageWin))
                            Capsule()
                                .fill(Color.red.opacity(0.72))
                                .frame(width: qualityBarWidth(proxy.size.width, value: abs(summary.averageLoss)))
                        }
                    }
                    .frame(height: 10)
                }
            }
            .frame(height: 210, alignment: .top)
        }
    }

    private func qualityBarWidth(_ totalWidth: CGFloat, value: Double) -> CGFloat {
        let maxValue = max(max(summary.averageWin, abs(summary.averageLoss)), 1)
        return max(totalWidth * CGFloat(value / maxValue), value > 0 ? 8 : 0)
    }
}

private struct QualityMetricRow: View {
    let title: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }
}

private struct SymbolPnLRanking: View {
    let rows: [SymbolPnLRow]
    let amountText: (Double) -> String
    let amountColor: (Double) -> Color
    let onSelect: (SymbolPnLRow) -> Void

    private var maxMagnitude: Double {
        max(rows.map { abs($0.pnl) }.max() ?? 0, 1)
    }

    var body: some View {
        ChartCard(title: "标的盈亏排行", subtitle: rows.isEmpty ? "暂无标的" : "按影响排序", subtitleColor: .secondary) {
            if rows.isEmpty {
                ChartEmptyState(text: "还没有标的盈亏")
            } else {
                VStack(spacing: 12) {
                    ForEach(rows) { row in
                        Button {
                            onSelect(row)
                        } label: {
                            SymbolRankRow(
                                row: row,
                                maxMagnitude: maxMagnitude,
                                amountText: amountText,
                                amountColor: amountColor
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(height: 210, alignment: .top)
            }
        }
    }
}

private struct ChartPointCallout: View {
    let title: String
    let primaryText: String
    let primaryLabel: String
    let secondaryText: String
    let secondaryLabel: String
    let color: Color
    let canOpen: Bool
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(primaryLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(primaryText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                Text(secondaryLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(secondaryText)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()

            Button {
                onOpen()
            } label: {
                Image(systemName: "arrow.up.forward.square")
            }
            .buttonStyle(.borderless)
            .disabled(!canOpen)
            .help(canOpen ? "查看当天交易" : "当天没有交易")
        }
        .padding(10)
        .background(Color.secondarySystemBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct SymbolTradeListView: View {
    let ticker: String
    let trades: [TradeEntry]
    let amountText: (Double) -> String
    let amountColor: (Double) -> Color

    private var pnlTotal: Double {
        trades.reduce(0) { total, trade in
            total + (trade.pnl.map { MoneyFormatters.convertedToHKD($0, from: MoneyFormatters.effectiveTradeCurrency(for: trade)) } ?? 0)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    StatSheetMetricTile(title: "交易笔数", value: "\(trades.count)", icon: "number.circle", color: .accentColor)
                    StatSheetMetricTile(title: "周期盈亏", value: amountText(pnlTotal), icon: "dollarsign.circle", color: amountColor(pnlTotal))
                }

                if trades.isEmpty {
                    ContentUnavailableView("没有交易", systemImage: "chart.line.uptrend.xyaxis")
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
        .navigationTitle(ticker)
    }
}

private struct StatSheetMetricTile: View {
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

private struct SymbolRankRow: View {
    let row: SymbolPnLRow
    let maxMagnitude: Double
    let amountText: (Double) -> String
    let amountColor: (Double) -> Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.ticker)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(row.tradeCount)笔")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(amountText(row.pnl))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amountColor(row.pnl))
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))

                    Capsule()
                        .fill(amountColor(row.pnl).opacity(0.72))
                        .frame(width: max(proxy.size.width * abs(row.pnl) / maxMagnitude, 6))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    let subtitleColor: Color
    private let content: Content

    init(
        title: String,
        subtitle: String,
        subtitleColor: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleColor = subtitleColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(subtitleColor)
                    .monospacedDigit()
            }

            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ChartEmptyState: View {
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
    }
}

private func nearestPoint(to date: Date?, in points: [DailyPnLPoint]) -> DailyPnLPoint? {
    guard let date else { return nil }
    return points.min { first, second in
        abs(first.date.timeIntervalSince(date)) < abs(second.date.timeIntervalSince(date))
    }
}

private func compactMoney(_ value: Double) -> String {
    let absolute = abs(value)
    let sign = value < 0 ? "-" : ""

    if absolute >= 10_000 {
        return "\(sign)\(String(format: "%.1f", absolute / 10_000))万"
    }
    if absolute >= 1_000 {
        return "\(sign)\(String(format: "%.1f", absolute / 1_000))k"
    }
    return "\(sign)\(String(format: "%.0f", absolute))"
}
