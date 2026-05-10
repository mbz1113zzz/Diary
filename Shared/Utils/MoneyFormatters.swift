import Foundation

struct ExchangeRateOption: Identifiable {
    let currencyCode: String
    let displayName: String
    let defaultRate: Double
    let storageKey: String

    var id: String { currencyCode }
}

enum MoneyFormatters {
    static let currencyCode = "HKD"
    static let exchangeRateOptions: [ExchangeRateOption] = [
        ExchangeRateOption(currencyCode: "USD", displayName: "美元 USD", defaultRate: 7.8, storageKey: "exchangeRateUSDToHKD"),
        ExchangeRateOption(currencyCode: "TWD", displayName: "新台币 TWD", defaultRate: 0.249, storageKey: "exchangeRateTWDToHKD"),
        ExchangeRateOption(currencyCode: "KRW", displayName: "韩元 KRW", defaultRate: 0.0055, storageKey: "exchangeRateKRWToHKD")
    ]

    private static let knownTaiwanTickers: Set<String> = ["6830"]

    static func native(_ value: Double, currency: String?, signed: Bool = false) -> String {
        let normalized = normalizedCurrency(currency)
        let sign = signed && value > 0 ? "+" : ""
        return "\(sign)\(normalized) \(String(format: "%.2f", value))"
    }

    static func hkd(_ value: Double, sourceCurrency: String? = nil, signed: Bool = false) -> String {
        let convertedValue = convertedToHKD(value, from: sourceCurrency)
        let sign = signed && convertedValue > 0 ? "+" : ""
        return "\(sign)\(currencyCode) \(String(format: "%.2f", convertedValue))"
    }

    static func hkdWithOriginal(_ value: Double, sourceCurrency: String?, signed: Bool = false) -> String {
        let normalized = normalizedCurrency(sourceCurrency)
        let hkdText = hkd(value, sourceCurrency: normalized, signed: signed)
        guard normalized != currencyCode else { return hkdText }
        return "\(hkdText) (\(native(value, currency: normalized, signed: signed)))"
    }

    static func convertedToHKD(_ value: Double, from sourceCurrency: String?) -> Double {
        value * hkdRate(for: sourceCurrency)
    }

    static func hkdRate(for sourceCurrency: String?) -> Double {
        let normalized = normalizedCurrency(sourceCurrency)
        guard normalized != currencyCode else { return 1 }
        guard let option = exchangeRateOptions.first(where: { $0.currencyCode == normalized }) else {
            return 1
        }

        let storedValue = UserDefaults.standard.object(forKey: option.storageKey) as? Double
        guard let storedValue, storedValue > 0 else { return option.defaultRate }
        return storedValue
    }

    static func defaultHKDRate(for currency: String) -> Double {
        let normalized = normalizedCurrency(currency)
        if normalized == currencyCode { return 1 }
        return exchangeRateOptions.first(where: { $0.currencyCode == normalized })?.defaultRate ?? 1
    }

    static func setHKDRate(_ rate: Double, for currency: String) {
        let normalized = normalizedCurrency(currency)
        guard let option = exchangeRateOptions.first(where: { $0.currencyCode == normalized }), rate > 0 else { return }
        UserDefaults.standard.set(rate, forKey: option.storageKey)
    }

    static func resetHKDRates() {
        for option in exchangeRateOptions {
            UserDefaults.standard.removeObject(forKey: option.storageKey)
        }
    }

    // MARK: Shared formatting helpers

    static func hkdSigned(_ value: Double) -> String {
        hkd(value, signed: true)
    }

    static func percentage(_ value: Double) -> String {
        "\(String(format: "%.1f", value * 100))%"
    }

    static func signedPercentage(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value * 100))%"
    }

    static func normalizedCurrency(_ currency: String?) -> String {
        let code = currency?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        return code.isEmpty ? "HKD" : code
    }

    static func effectiveTradeCurrency(for trade: TradeEntry) -> String {
        effectiveTradeCurrency(
            ticker: trade.ticker,
            reportedCurrency: trade.currency,
            exchange: nil,
            isIBKRImported: trade.ibkrImported
        )
    }

    static func effectiveTradeCurrency(
        ticker: String,
        reportedCurrency: String?,
        exchange: String?,
        isIBKRImported: Bool = false
    ) -> String {
        if let inferred = inferredCurrency(fromExchange: exchange) {
            return inferred
        }

        if let inferred = inferredCurrency(fromTicker: ticker, allowLegacyIBKRFallback: isIBKRImported) {
            return inferred
        }

        return normalizedCurrency(reportedCurrency)
    }

    private static func inferredCurrency(fromExchange exchange: String?) -> String? {
        let value = exchange?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        guard !value.isEmpty else { return nil }

        if value.contains("TWSE") || value.contains("TSE") || value.contains("TPEX") || value.contains("TAIWAN") {
            return "TWD"
        }
        if value.contains("SEHK") || value.contains("HKEX") || value.contains("HONG KONG") {
            return "HKD"
        }
        if value.contains("KSE") || value.contains("KRX") || value.contains("KOSDAQ") {
            return "KRW"
        }
        if value.contains("NASDAQ") || value.contains("NYSE") || value.contains("ARCA") || value.contains("AMEX") {
            return "USD"
        }
        return nil
    }

    private static func inferredCurrency(fromTicker ticker: String, allowLegacyIBKRFallback: Bool) -> String? {
        let value = ticker
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !value.isEmpty else { return nil }

        if value.hasSuffix(".TW") || value.hasSuffix(".TWO") {
            return "TWD"
        }
        if value.hasSuffix(".HK") {
            return "HKD"
        }
        if value.hasSuffix(".KS") || value.hasSuffix(".KQ") {
            return "KRW"
        }

        guard allowLegacyIBKRFallback else { return nil }

        if knownTaiwanTickers.contains(value) {
            return "TWD"
        }

        if isUSOptionSymbol(value) || isUSTickerSymbol(value) {
            return "USD"
        }

        return nil
    }

    private static func isUSTickerSymbol(_ ticker: String) -> Bool {
        ticker.range(of: #"^[A-Z]{1,6}$"#, options: .regularExpression) != nil
    }

    private static func isUSOptionSymbol(_ ticker: String) -> Bool {
        ticker.range(of: #"^[A-Z]{1,6}\s+\d{6}[CP]\d{8}$"#, options: .regularExpression) != nil
    }
}
