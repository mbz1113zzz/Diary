import SwiftUI
import SwiftData

struct StatisticsDashboardView: View {
    @Query(sort: [SortDescriptor(\TradeEntry.date, order: .reverse)])
    private var trades: [TradeEntry]
    @State private var period: TradeStatsPeriod = .week

    private var summary: TradeStatsSummary {
        TradeAnalytics.summary(for: period, trades: trades)
    }

    private var strategyRows: [(tag: String, count: Int, pnl: Double)] {
        var rows: [String: (count: Int, pnl: Double)] = [:]
        for trade in trades {
            for tag in trade.strategyTags {
                let current = rows[tag] ?? (0, 0)
                rows[tag] = (current.count + 1, current.pnl + (trade.pnl ?? 0))
            }
        }
        return rows
            .map { (tag: $0.key, count: $0.value.count, pnl: $0.value.pnl) }
            .sorted { $0.count == $1.count ? $0.tag < $1.tag : $0.count > $1.count }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("周期", selection: $period) {
                    ForEach(TradeStatsPeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
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

                VStack(alignment: .leading, spacing: 10) {
                    Text("策略标签")
                        .font(.headline)

                    if strategyRows.isEmpty {
                        Text("还没有策略标签")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(strategyRows, id: \.tag) { row in
                            HStack {
                                Text(row.tag)
                                Spacer()
                                Text("\(row.count)笔")
                                    .foregroundStyle(.secondary)
                                Text(signedMoney(row.pnl))
                                    .foregroundStyle(pnlColor(row.pnl))
                                    .monospacedDigit()
                            }
                            .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color.systemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.secondarySystemBackground.opacity(0.45))
        .navigationTitle("统计")
    }

    private func signedMoney(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)$\(String(format: "%.2f", value))"
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
