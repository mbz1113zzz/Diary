import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum TradeExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"

    var id: Self { self }

    var contentType: UTType {
        switch self {
        case .csv:
            return UTType(filenameExtension: "csv") ?? .plainText
        case .json:
            return .json
        }
    }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        }
    }
}

struct TextExportDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [UTType(filenameExtension: "csv") ?? .plainText, .json, .plainText]
    }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

enum TradeExportBuilder {
    static func document(for format: TradeExportFormat, trades: [TradeEntry]) -> TextExportDocument {
        switch format {
        case .csv:
            return TextExportDocument(text: csv(for: trades))
        case .json:
            return TextExportDocument(text: json(for: trades))
        }
    }

    static func filename(for format: TradeExportFormat, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "StockDiary-Trades-\(formatter.string(from: date)).\(format.fileExtension)"
    }

    static func csv(for trades: [TradeEntry]) -> String {
        let header = [
            "date", "ticker", "direction", "price", "quantity", "pnl", "pnlPercent",
            "entryReason", "exitReason", "emotion", "strategyTags", "followedPlan",
            "hadStopLossPlan", "chasedMove", "emotionalTrade", "reviewConclusion",
            "mistakeTags", "notes", "createdAt"
        ].joined(separator: ",")

        let rows = trades.map { trade in
            [
                DateFormatters.exportDate.string(from: trade.date),
                trade.ticker,
                trade.direction,
                "\(trade.price)",
                "\(trade.quantity)",
                trade.pnl.map { "\($0)" } ?? "",
                trade.pnlPercent.map { "\($0)" } ?? "",
                trade.entryReason ?? "",
                trade.exitReason ?? "",
                trade.emotion ?? "",
                trade.strategyTags.joined(separator: "|"),
                boolText(trade.followedPlan),
                boolText(trade.hadStopLossPlan),
                boolText(trade.chasedMove),
                boolText(trade.emotionalTrade),
                trade.reviewConclusion ?? "",
                trade.mistakeTags.joined(separator: "|"),
                trade.notes ?? "",
                DateFormatters.exportDate.string(from: trade.createdAt)
            ].map(escapeCSV).joined(separator: ",")
        }

        return ([header] + rows).joined(separator: "\n")
    }

    static func json(for trades: [TradeEntry]) -> String {
        let snapshots = trades.map(TradeExportSnapshot.init)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshots),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    private static func escapeCSV(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func boolText(_ value: Bool?) -> String {
        guard let value else { return "" }
        return value ? "true" : "false"
    }
}

private struct TradeExportSnapshot: Encodable {
    let id: UUID
    let date: String
    let ticker: String
    let direction: String
    let price: Double
    let quantity: Int
    let pnl: Double?
    let pnlPercent: Double?
    let entryReason: String?
    let exitReason: String?
    let emotion: String?
    let strategyTags: [String]
    let followedPlan: Bool?
    let hadStopLossPlan: Bool?
    let chasedMove: Bool?
    let emotionalTrade: Bool?
    let reviewConclusion: String?
    let mistakeTags: [String]
    let notes: String?
    let createdAt: String

    init(trade: TradeEntry) {
        id = trade.id
        date = DateFormatters.exportDate.string(from: trade.date)
        ticker = trade.ticker
        direction = trade.direction
        price = trade.price
        quantity = trade.quantity
        pnl = trade.pnl
        pnlPercent = trade.pnlPercent
        entryReason = trade.entryReason
        exitReason = trade.exitReason
        emotion = trade.emotion
        strategyTags = trade.strategyTags
        followedPlan = trade.followedPlan
        hadStopLossPlan = trade.hadStopLossPlan
        chasedMove = trade.chasedMove
        emotionalTrade = trade.emotionalTrade
        reviewConclusion = trade.reviewConclusion
        mistakeTags = trade.mistakeTags
        notes = trade.notes
        createdAt = DateFormatters.exportDate.string(from: trade.createdAt)
    }
}
