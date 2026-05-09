import SwiftUI
import SwiftData

struct TradeEditorView: View {
    @Bindable var trade: TradeEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let directions = ["买入", "卖出"]
    private let emotions = ["冷静", "兴奋", "紧张", "犹豫", "恐惧", "贪婪"]

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
                    Text("价格")
                    TextField("0.00", value: $trade.price, format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
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
                    Text("盈亏金额")
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
        }
        .formStyle(.grouped)
    }
}
