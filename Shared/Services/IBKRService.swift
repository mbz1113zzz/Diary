import Foundation

// MARK: - Flex Web Service

final class IBKRService {

    // Flex Web Service endpoints
    private let sendRequestURL = "https://ndcdyn.interactivebrokers.com/AccountManagement/FlexWebService/SendRequest"
    private let getStatementURL = "https://ndcdyn.interactivebrokers.com/AccountManagement/FlexWebService/GetStatement"

    private let session: URLSession

    init() {
        self.session = URLSession.shared
    }

    // MARK: - Flex Query

    /// Step 1: Send a Flex Query request, returns a reference code
    func sendFlexRequest(token: String, queryId: String) async throws -> String {
        let urlString = "\(sendRequestURL)?t=\(token)&q=\(queryId)&v=3"
        guard let url = URL(string: urlString) else {
            throw IBKRError.invalidConfiguration
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw IBKRError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        // Parse XML response to get ReferenceCode
        let xmlString = String(data: data, encoding: .utf8) ?? ""

        // Check for error
        if xmlString.contains("<Status>Fail</Status>") || xmlString.contains("<Status>Warn</Status>") {
            let errorMessage = extractXMLValue(from: xmlString, tag: "ErrorMessage") ?? "未知错误"
            throw IBKRError.flexQueryError(errorMessage)
        }

        guard let referenceCode = extractXMLValue(from: xmlString, tag: "ReferenceCode") else {
            throw IBKRError.decodingFailed
        }

        return referenceCode
    }

    /// Step 2: Get the Flex Query statement using the reference code
    func getFlexStatement(token: String, referenceCode: String) async throws -> [FlexTrade] {
        let urlString = "\(getStatementURL)?t=\(token)&q=\(referenceCode)&v=3"
        guard let url = URL(string: urlString) else {
            throw IBKRError.invalidConfiguration
        }

        // IBKR may need a few seconds to prepare the statement
        // Retry up to 3 times with delay
        var lastError: Error = IBKRError.decodingFailed
        for attempt in 0..<3 {
            if attempt > 0 {
                try await Task.sleep(for: .seconds(2))
            }

            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw IBKRError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
            }

            let xmlString = String(data: data, encoding: .utf8) ?? ""

            // Check if still processing
            if xmlString.contains("<Status>Warn</Status>") && xmlString.contains("Please try again") {
                lastError = IBKRError.flexQueryError("报表准备中，正在重试...")
                continue
            }

            // Check for error
            if xmlString.contains("<Status>Fail</Status>") {
                let errorMessage = extractXMLValue(from: xmlString, tag: "ErrorMessage") ?? "未知错误"
                throw IBKRError.flexQueryError(errorMessage)
            }

            // Parse trades from XML
            let trades = parseFlexTrades(from: xmlString)
            return trades
        }

        throw lastError
    }

    /// Combined: send request + get statement
    func fetchTrades(token: String, queryId: String) async throws -> [FlexTrade] {
        let referenceCode = try await sendFlexRequest(token: token, queryId: queryId)
        // Wait a moment for IBKR to prepare
        try await Task.sleep(for: .seconds(1))
        return try await getFlexStatement(token: token, referenceCode: referenceCode)
    }

    // MARK: - XML Parsing

    private func extractXMLValue(from xml: String, tag: String) -> String? {
        guard let startRange = xml.range(of: "<\(tag)>"),
              let endRange = xml.range(of: "</\(tag)>") else {
            return nil
        }
        let value = String(xml[startRange.upperBound..<endRange.lowerBound])
        return value.isEmpty ? nil : value
    }

    private func parseFlexTrades(from xml: String) -> [FlexTrade] {
        var trades: [FlexTrade] = []

        // Split by <Trade or <Order tags
        let tradePattern = xml.components(separatedBy: "<Trade ")
        for (index, component) in tradePattern.enumerated() {
            guard index > 0 else { continue } // skip first (before any <Trade)
            guard let endIndex = component.range(of: "/>") ?? component.range(of: ">") else { continue }

            let attributes = String(component[component.startIndex..<endIndex.lowerBound])

            guard let symbol = extractAttribute("symbol", from: attributes),
                  let tradeId = extractAttribute("tradeID", from: attributes) ?? extractAttribute("ibExecID", from: attributes) else {
                continue
            }

            let buySell = extractAttribute("buySell", from: attributes) ?? ""
            let price = extractAttribute("tradePrice", from: attributes) ?? extractAttribute("price", from: attributes) ?? "0"
            let quantity = extractAttribute("quantity", from: attributes) ?? "0"
            let dateTime = extractAttribute("dateTime", from: attributes) ?? extractAttribute("tradeDate", from: attributes) ?? ""
            let realizedPnl = extractAttribute("fifoPnlRealized", from: attributes) ?? extractAttribute("realizedPnl", from: attributes)
            let exchange = extractAttribute("exchange", from: attributes)

            let trade = FlexTrade(
                tradeId: tradeId,
                symbol: symbol,
                buySell: buySell,
                price: price,
                quantity: quantity,
                dateTime: dateTime,
                realizedPnl: realizedPnl,
                exchange: exchange
            )
            trades.append(trade)
        }

        return trades
    }

    private func extractAttribute(_ name: String, from attributes: String) -> String? {
        let pattern = "\(name)=\""
        guard let startRange = attributes.range(of: pattern) else { return nil }
        let afterStart = attributes[startRange.upperBound...]
        guard let endQuote = afterStart.firstIndex(of: "\"") else { return nil }
        let value = String(afterStart[afterStart.startIndex..<endQuote])
        return value.isEmpty ? nil : value
    }

    // MARK: - Date Formatter

    /// Flex Query date format: "yyyyMMdd;HHmmss" or "yyyyMMdd"
    static let flexDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd;HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        return formatter
    }()

    static let flexDateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        return formatter
    }()
}

// MARK: - Models

struct FlexTrade {
    let tradeId: String
    let symbol: String
    let buySell: String  // "BUY" or "SELL"
    let price: String
    let quantity: String
    let dateTime: String
    let realizedPnl: String?
    let exchange: String?
}

// MARK: - Error

enum IBKRError: LocalizedError {
    case invalidConfiguration
    case httpError(Int)
    case decodingFailed
    case flexQueryError(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "IBKR 配置无效，请检查 Token 和 Query ID"
        case .httpError(let code):
            return "IBKR 请求失败，HTTP 状态码: \(code)"
        case .decodingFailed:
            return "解析 IBKR 响应数据失败"
        case .flexQueryError(let message):
            return "IBKR Flex Query 错误: \(message)"
        }
    }
}
