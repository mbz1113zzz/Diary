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
        let xmlString = try await getFlexStatementXML(token: token, referenceCode: referenceCode)
        return parseFlexTrades(from: xmlString)
    }

    /// Step 2: Get the raw Flex Query XML statement using the reference code
    func getFlexStatementXML(token: String, referenceCode: String) async throws -> String {
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

            return xmlString
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

    func fetchFlexPositions(token: String, queryId: String) async throws -> FlexPositionReport {
        let referenceCode = try await sendFlexRequest(token: token, queryId: queryId)
        try await Task.sleep(for: .seconds(1))
        let xmlString = try await getFlexStatementXML(token: token, referenceCode: referenceCode)
        return parseFlexPositions(from: xmlString)
    }

    // MARK: - Market Data (Client Portal API)

    func fetchMarketSnapshots(tickers: [String], host: String = "localhost", port: Int = 5000) async throws -> [MarketSnapshot] {
        guard !tickers.isEmpty else { return [] }

        let tickerList = tickers.joined(separator: ",")
        let urlString = "https://\(host):\(port)/v1/api/iserver/marketdata/snapshot?conids=\(tickerList)&fields=31,55,83,84"
        guard let url = URL(string: urlString) else {
            throw IBKRError.invalidConfiguration
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw IBKRError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw IBKRError.decodingFailed
        }

        let now = Date()
        return jsonArray.compactMap { item in
            guard let lastPrice = item["31"] as? Double,
                  let change = item["83"] as? Double,
                  let changePercent = item["84"] as? Double else {
                return nil
            }
            let conidStr = String(item["conid"] as? Int ?? 0)
            return MarketSnapshot(
                ticker: conidStr,
                lastPrice: lastPrice,
                change: change,
                changePercent: changePercent / 100,
                timestamp: now
            )
        }
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
            let currency = extractAttribute("currency", from: attributes) ?? extractAttribute("tradeCurrency", from: attributes)

            let trade = FlexTrade(
                tradeId: tradeId,
                symbol: symbol,
                buySell: buySell,
                price: price,
                quantity: quantity,
                dateTime: dateTime,
                realizedPnl: realizedPnl,
                exchange: exchange,
                currency: currency
            )
            trades.append(trade)
        }

        return trades
    }

    private func parseFlexPositions(from xml: String) -> FlexPositionReport {
        let openPositionAttributes = extractElementAttributes(named: "OpenPosition", from: xml)
        let fallbackPositionAttributes = extractElementAttributes(named: "Position", from: xml)
        let positionAttributes = openPositionAttributes.isEmpty ? fallbackPositionAttributes : openPositionAttributes

        let positions: [FlexPosition] = positionAttributes.compactMap { attributes in
            guard let symbol = extractAttribute("symbol", from: attributes)
                    ?? extractAttribute("underlyingSymbol", from: attributes)
                    ?? extractAttribute("description", from: attributes) else {
                return nil
            }

            return FlexPosition(
                accountId: extractAttribute("accountId", from: attributes) ?? extractAttribute("account", from: attributes),
                conid: extractAttribute("conid", from: attributes) ?? extractAttribute("conId", from: attributes),
                symbol: symbol,
                description: extractAttribute("description", from: attributes),
                assetCategory: extractAttribute("assetCategory", from: attributes) ?? extractAttribute("assetClass", from: attributes),
                currency: extractAttribute("currency", from: attributes),
                quantity: extractAttribute("quantity", from: attributes) ?? extractAttribute("position", from: attributes) ?? "0",
                averageCost: extractAttribute("costBasisPrice", from: attributes)
                    ?? extractAttribute("avgPrice", from: attributes)
                    ?? extractAttribute("averageCost", from: attributes),
                marketPrice: extractAttribute("markPrice", from: attributes)
                    ?? extractAttribute("marketPrice", from: attributes)
                    ?? extractAttribute("closePrice", from: attributes),
                marketValue: extractAttribute("positionValue", from: attributes)
                    ?? extractAttribute("marketValue", from: attributes)
                    ?? extractAttribute("mktValue", from: attributes),
                unrealizedPnl: extractAttribute("fifoPnlUnrealized", from: attributes)
                    ?? extractAttribute("unrealizedPnl", from: attributes),
                realizedPnl: extractAttribute("fifoPnlRealized", from: attributes)
                    ?? extractAttribute("realizedPnl", from: attributes)
            )
        }

        return FlexPositionReport(
            positions: positions,
            openPositionNodeCount: openPositionAttributes.count,
            positionNodeCount: fallbackPositionAttributes.count,
            tradeNodeCount: extractElementAttributes(named: "Trade", from: xml).count,
            cashReportNodeCount: extractElementAttributes(named: "CashReport", from: xml).count,
            statementTagNames: extractStatementTagNames(from: xml)
        )
    }

    private func extractElementAttributes(named elementName: String, from xml: String) -> [String] {
        let pattern = #"<(?:[A-Za-z_][A-Za-z0-9_.-]*:)?"# + NSRegularExpression.escapedPattern(for: elementName) + #"\b([^>]*)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        return regex.matches(in: xml, range: range).compactMap { match in
            guard let matchRange = Range(match.range(at: 1), in: xml) else { return nil }
            return String(xml[matchRange])
        }
    }

    private func extractAttribute(_ name: String, from attributes: String) -> String? {
        let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: name) + #"\s*=\s*(['"])(.*?)\1"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(attributes.startIndex..<attributes.endIndex, in: attributes)
        guard let match = regex.firstMatch(in: attributes, range: range),
              let valueRange = Range(match.range(at: 2), in: attributes) else {
            return nil
        }
        let value = String(attributes[valueRange]).decodedXMLAttribute
        return value.isEmpty ? nil : value
    }

    private func extractStatementTagNames(from xml: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"<\/?([A-Za-z_][A-Za-z0-9_.-]*:)?([A-Za-z_][A-Za-z0-9_.-]*)\b"#) else {
            return []
        }
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        var names: [String] = []
        var seen: Set<String> = []
        for match in regex.matches(in: xml, range: range) {
            guard let nameRange = Range(match.range(at: 2), in: xml) else { continue }
            let name = String(xml[nameRange])
            guard !seen.contains(name), !name.hasPrefix("?") else { continue }
            seen.insert(name)
            names.append(name)
            if names.count >= 12 { break }
        }
        return names
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

struct MarketSnapshot: Identifiable {
    let ticker: String
    let lastPrice: Double
    let change: Double
    let changePercent: Double
    let timestamp: Date

    var id: String { ticker }
}

struct FlexTrade {
    let tradeId: String
    let symbol: String
    let buySell: String  // "BUY" or "SELL"
    let price: String
    let quantity: String
    let dateTime: String
    let realizedPnl: String?
    let exchange: String?
    let currency: String?
}

struct FlexPosition: Identifiable, Codable {
    let account: String?
    let conid: String?
    let symbol: String
    let positionDescription: String?
    let assetCategory: String?
    let currency: String?
    let position: Double
    let averagePrice: Double?
    let marketValue: Double?
    let unrealizedPnl: Double?
    let realizedPnl: Double?
    let lastPrice: Double?

    var id: String {
        let key = [account, conid, symbol]
            .compactMap { $0 }
            .joined(separator: "-")
        return key.isEmpty ? symbol : key
    }

    var displayName: String {
        if let positionDescription, !positionDescription.isEmpty, positionDescription != symbol {
            return "\(symbol) · \(positionDescription)"
        }
        return symbol
    }

    init(
        accountId: String?,
        conid: String?,
        symbol: String,
        description: String?,
        assetCategory: String?,
        currency: String?,
        quantity: String,
        averageCost: String?,
        marketPrice: String?,
        marketValue: String?,
        unrealizedPnl: String?,
        realizedPnl: String?
    ) {
        self.account = accountId
        self.conid = conid
        self.symbol = symbol
        self.positionDescription = description
        self.assetCategory = assetCategory
        self.currency = currency
        self.position = Double(quantity.replacingOccurrences(of: ",", with: "")) ?? 0
        self.averagePrice = averageCost.flatMap { Double($0.replacingOccurrences(of: ",", with: "")) }
        self.marketValue = marketValue.flatMap { Double($0.replacingOccurrences(of: ",", with: "")) }
        self.unrealizedPnl = unrealizedPnl.flatMap { Double($0.replacingOccurrences(of: ",", with: "")) }
        self.realizedPnl = realizedPnl.flatMap { Double($0.replacingOccurrences(of: ",", with: "")) }
        self.lastPrice = marketPrice.flatMap { Double($0.replacingOccurrences(of: ",", with: "")) }
    }
}

struct FlexPositionReport {
    let positions: [FlexPosition]
    let openPositionNodeCount: Int
    let positionNodeCount: Int
    let tradeNodeCount: Int
    let cashReportNodeCount: Int
    let statementTagNames: [String]

    var diagnosticText: String {
        var parts = [
            "OpenPosition: \(openPositionNodeCount)",
            "Position: \(positionNodeCount)",
            "Trade: \(tradeNodeCount)",
            "CashReport: \(cashReportNodeCount)"
        ]
        if !statementTagNames.isEmpty {
            parts.append("标签: \(statementTagNames.joined(separator: ", "))")
        }
        return parts.joined(separator: "；")
    }
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

private extension String {
    var decodedXMLAttribute: String {
        replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
