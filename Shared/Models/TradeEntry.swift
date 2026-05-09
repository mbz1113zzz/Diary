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
        self.createdAt = createdAt
    }
}
