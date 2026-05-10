import SwiftUI
import SwiftData

struct TradeEditorView: View {
    @Bindable var trade: TradeEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let directions = ["买入", "卖出"]
    private let currencies = ["HKD", "USD", "TWD", "KRW"]
    private let emotions = ["冷静", "兴奋", "紧张", "犹豫", "恐惧", "贪婪"]
    private let strategyOptions = ["突破", "回调", "事件驱动"]
    private let mistakeOptions = ["FOMO", "提前止盈", "扛单", "无计划", "仓位过重", "没等确认"]

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("股票代码", text: $trade.ticker)
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
                Picker("方向", selection: $trade.direction) {
                    ForEach(directions, id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("价格（原币种）")
                    TextField("0.00", value: $trade.price, format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                Picker("货币", selection: Binding(
                    get: { MoneyFormatters.effectiveTradeCurrency(for: trade) },
                    set: { trade.currency = $0 }
                )) {
                    ForEach(currencies, id: \.self) { currency in
                        Text(currency).tag(currency)
                    }
                }
                HStack {
                    Text("数量")
                    TextField("0", value: $trade.quantity, format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
            }

            Section("盈亏") {
                HStack {
                    Text("盈亏金额（原币种）")
                    TextField("0.00", value: $trade.pnl, format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                HStack {
                    Text("盈亏比例 %")
                    TextField("0.0", value: $trade.pnlPercent, format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            }

            Section("复盘") {
                TextField("入场理由", text: Binding(
                    get: { trade.entryReason ?? "" },
                    set: { trade.entryReason = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...4)

                TextField("出场理由", text: Binding(
                    get: { trade.exitReason ?? "" },
                    set: { trade.exitReason = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...4)

                Picker("情绪", selection: Binding(
                    get: { trade.emotion ?? "" },
                    set: { trade.emotion = $0.isEmpty ? nil : $0 }
                )) {
                    Text("选择情绪").tag("")
                    ForEach(emotions, id: \.self) { Text($0).tag($0) }
                }

                TextField("复盘笔记", text: Binding(
                    get: { trade.notes ?? "" },
                    set: { trade.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(3...6)
            }

            Section("策略标签") {
                FlowTagPicker(
                    options: strategyOptions,
                    selection: $trade.strategyTags,
                    tint: .accentColor
                )
            }

            Section("纪律复盘") {
                Toggle("按计划交易", isOn: Binding(
                    get: { trade.followedPlan ?? false },
                    set: { trade.followedPlan = $0 }
                ))
                Toggle("入场前写好止损", isOn: Binding(
                    get: { trade.hadStopLossPlan ?? false },
                    set: { trade.hadStopLossPlan = $0 }
                ))
                Toggle("追高 / 杀跌", isOn: Binding(
                    get: { trade.chasedMove ?? false },
                    set: { trade.chasedMove = $0 }
                ))
                Toggle("情绪化交易", isOn: Binding(
                    get: { trade.emotionalTrade ?? false },
                    set: { trade.emotionalTrade = $0 }
                ))

                TextField("复盘结论", text: Binding(
                    get: { trade.reviewConclusion ?? "" },
                    set: { trade.reviewConclusion = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...5)
            }

            Section("错误标签") {
                FlowTagPicker(
                    options: mistakeOptions,
                    selection: $trade.mistakeTags,
                    tint: .red
                )
            }
        }
        .formStyle(.grouped)
    }
}

struct FlowTagPicker: View {
    let options: [String]
    @Binding var selection: [String]
    var tint: Color = .accentColor

    var body: some View {
        FlexibleFlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    toggle(option)
                } label: {
                    Label(option, systemImage: selection.contains(option) ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selection.contains(option) ? tint.opacity(0.14) : Color.secondarySystemBackground)
                        .foregroundStyle(selection.contains(option) ? tint : Color.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(_ option: String) {
        if selection.contains(option) {
            selection.removeAll { $0 == option }
        } else {
            selection.append(option)
        }
    }
}

struct FlexibleFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        let rows = rows(for: subviews, maxWidth: maxWidth)
        return CGSize(
            width: maxWidth,
            height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * spacing
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [(height: CGFloat, width: CGFloat)] {
        var rows: [(height: CGFloat, width: CGFloat)] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = currentWidth == 0 ? size.width : currentWidth + spacing + size.width
            if currentWidth > 0 && nextWidth > maxWidth {
                rows.append((currentHeight, currentWidth))
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if currentWidth > 0 {
            rows.append((currentHeight, currentWidth))
        }
        return rows
    }
}
