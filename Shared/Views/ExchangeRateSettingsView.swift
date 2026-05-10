import SwiftUI

struct ExchangeRateSettingsView: View {
    @AppStorage("exchangeRateUSDToHKD") private var usdRate = MoneyFormatters.defaultHKDRate(for: "USD")
    @AppStorage("exchangeRateTWDToHKD") private var twdRate = MoneyFormatters.defaultHKDRate(for: "TWD")
    @AppStorage("exchangeRateKRWToHKD") private var krwRate = MoneyFormatters.defaultHKDRate(for: "KRW")

    var body: some View {
        Section("汇率折算") {
            ExchangeRateRow(
                title: "美元 USD",
                currencyCode: "USD",
                rate: $usdRate
            )
            ExchangeRateRow(
                title: "新台币 TWD",
                currencyCode: "TWD",
                rate: $twdRate
            )
            ExchangeRateRow(
                title: "韩元 KRW",
                currencyCode: "KRW",
                rate: $krwRate
            )

            Button {
                resetRates()
            } label: {
                Label("恢复默认汇率", systemImage: "arrow.counterclockwise")
            }

            Text("用于统计、持仓和盈亏折算。原始交易金额仍按原币种显示。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func resetRates() {
        usdRate = MoneyFormatters.defaultHKDRate(for: "USD")
        twdRate = MoneyFormatters.defaultHKDRate(for: "TWD")
        krwRate = MoneyFormatters.defaultHKDRate(for: "KRW")
    }
}

private struct ExchangeRateRow: View {
    let title: String
    let currencyCode: String
    @Binding var rate: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text("1 \(currencyCode) = \(String(format: "%.4f", rate)) HKD")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            TextField("汇率", value: positiveRateBinding, format: .number.precision(.fractionLength(0...6)))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        }
    }

    private var positiveRateBinding: Binding<Double> {
        Binding(
            get: { rate },
            set: { newValue in
                rate = max(newValue, 0.000001)
            }
        )
    }
}
