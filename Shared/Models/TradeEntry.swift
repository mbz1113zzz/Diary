import Foundation
import SwiftData

@Model
final class TradeEntry {
    var id: UUID
    var date: Date
    var ticker: String
    var direction: String
    var price: Double
    var quantity: Int
    var entryReason: String?
    var exitReason: String?
    var emotion: String?
    var pnl: Double?
    var pnlPercent: Double?
    var notes: String?
    var strategyTags: [String] = []
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        ticker: String = "",
        direction: String = "买入",
        price: Double = 0.0,
        quantity: Int = 0,
        entryReason: String? = nil,
        exitReason: String? = nil,
        emotion: String? = nil,
        pnl: Double? = nil,
        pnlPercent: Double? = nil,
        notes: String? = nil,
        strategyTags: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.ticker = ticker
        self.direction = direction
        self.price = price
        self.quantity = quantity
        self.entryReason = entryReason
        self.exitReason = exitReason
        self.emotion = emotion
        self.pnl = pnl
        self.pnlPercent = pnlPercent
        self.notes = notes
        self.strategyTags = strategyTags
        self.createdAt = createdAt
    }

    var isEmpty: Bool {
        ticker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        price == 0 &&
        quantity == 0 &&
        entryReason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false &&
        exitReason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false &&
        emotion == nil &&
        pnl == nil &&
        pnlPercent == nil &&
        notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false &&
        strategyTags.isEmpty
    }
}
