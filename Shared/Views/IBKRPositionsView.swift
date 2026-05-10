import SwiftUI

struct IBKRPositionsView: View {
    @AppStorage("ibkrFlexToken") private var flexToken = ""
    @AppStorage("ibkrFlexQueryId") private var flexQueryId = ""

    @State private var positions: [FlexPosition] = []
    @State private var isLoading = false
    @State private var statusText: String?
    @State private var diagnosticText: String?

    private let service = IBKRService()

    private var effectiveQueryId: String {
        flexQueryId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sortedPositions: [FlexPosition] {
        positions.sorted {
            abs($0.marketValue ?? 0) > abs($1.marketValue ?? 0)
        }
    }

    private var totalMarketValue: Double {
        positions.reduce(0) { total, position in
            total + (position.marketValue.map { MoneyFormatters.convertedToHKD($0, from: position.currency) } ?? 0)
        }
    }

    private var totalUnrealizedPnl: Double {
        positions.reduce(0) { total, position in
            total + (position.unrealizedPnl.map { MoneyFormatters.convertedToHKD($0, from: position.currency) } ?? 0)
        }
    }

    var body: some View {
        MascotCornerContainer {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    summaryGrid

                    if let statusText {
                        statusBanner(statusText)
                    }

                    if let diagnosticText {
                        statusBanner(diagnosticText)
                    }

                    if isLoading {
                        ProgressView("正在读取 IBKR 持仓...")
                            .frame(maxWidth: .infinity, minHeight: 160)
                    } else if sortedPositions.isEmpty {
                        ContentUnavailableView(
                            "暂无持仓",
                            systemImage: "briefcase",
                            description: Text("请确认 Flex 持仓 Query ID 已配置，并包含 Open Positions 字段")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("当前持仓")
                                .font(.headline)
                            ForEach(sortedPositions) { position in
                                IBKRPositionRow(position: position)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color.secondarySystemBackground.opacity(0.45))
        }
        .navigationTitle("持仓")
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await reload() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("刷新", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(isLoading)
            }
        }
        .task {
            guard positions.isEmpty else { return }
            await reload()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "briefcase")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("持仓")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("查看 IBKR 当前持仓和未实现盈亏")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            MetricCard(title: "持仓数量", value: "\(positions.count)", icon: "number", color: .accentColor, valueFont: .title3)
            MetricCard(title: "市值合计", value: MoneyFormatters.hkd(totalMarketValue), icon: "dollarsign.circle", color: Color.pnl(totalMarketValue), valueFont: .title3)
            MetricCard(title: "未实现盈亏", value: MoneyFormatters.hkdSigned(totalUnrealizedPnl), icon: "chart.line.uptrend.xyaxis", color: Color.pnl(totalUnrealizedPnl), valueFont: .title3)
        }
    }

    private func statusBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
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

    @MainActor
    private func reload() async {
        isLoading = true
        statusText = nil
        diagnosticText = nil

        let token = flexToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !effectiveQueryId.isEmpty else {
            statusText = "请先在设置中填写 Flex Token 和 Flex Query ID。"
            positions = []
            isLoading = false
            return
        }

        do {
            let report = try await service.fetchFlexPositions(token: token, queryId: effectiveQueryId)
            positions = report.positions
            diagnosticText = report.positions.isEmpty ? report.diagnosticText : nil
            statusText = positions.isEmpty ? "这个 Flex Query 里没有读取到持仓。请确认同一个 Query 同时包含 Open Positions 字段。" : nil
        } catch {
            statusText = "读取持仓失败：\(error.localizedDescription)"
            positions = []
            diagnosticText = nil
        }

        isLoading = false
    }

}

private struct IBKRPositionRow: View {
    let position: FlexPosition

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(position.displayName)
                        .font(.headline)
                    HStack(spacing: 8) {
                        if let assetCategory = position.assetCategory, !assetCategory.isEmpty {
                            Text(assetCategory)
                        }
                        if let currency = position.currency, !currency.isEmpty {
                            Text(currency)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text(quantity(position.position))
                    .font(.headline)
                    .monospacedDigit()
            }

            HStack {
                valueColumn("均价", value: nativeMoney(position.averagePrice, currency: position.currency))
                valueColumn("市值", value: money(position.marketValue, currency: position.currency), color: Color.pnl(converted(position.marketValue)))
                valueColumn("未实现", value: signedMoney(position.unrealizedPnl, currency: position.currency), color: Color.pnl(converted(position.unrealizedPnl)))
                valueColumn("最新", value: nativeMoney(position.lastPrice, currency: position.currency))
            }
        }
        .padding()
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func valueColumn(_ title: String, value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quantity(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.4f", value)
    }

    private func money(_ value: Double?, currency: String?) -> String {
        guard let value else { return "-" }
        return MoneyFormatters.hkd(value, sourceCurrency: currency)
    }

    private func nativeMoney(_ value: Double?, currency: String?) -> String {
        guard let value else { return "-" }
        return MoneyFormatters.native(value, currency: currency)
    }

    private func signedMoney(_ value: Double?, currency: String?) -> String {
        guard let value else { return "-" }
        return MoneyFormatters.hkd(value, sourceCurrency: currency, signed: true)
    }

    private func converted(_ value: Double?) -> Double {
        guard let value else { return 0 }
        return MoneyFormatters.convertedToHKD(value, from: position.currency)
    }
}

#if os(macOS)
import AppKit
#endif
