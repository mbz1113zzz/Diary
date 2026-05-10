import Foundation

enum MoneyFormatters {
    static let currencyCode = "HKD"
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
        switch normalizedCurrency(sourceCurrency) {
        case "HKD": return 1
        case "USD": return 7.8
        case "TWD": return 0.249
        case "KRW": return 0.0055
        default: return 1
        }
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
