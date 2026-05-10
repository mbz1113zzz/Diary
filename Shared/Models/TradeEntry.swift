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
    var currency: String?
    var entryReason: String?
    var exitReason: String?
    var emotion: String?
    var pnl: Double?
    var pnlPercent: Double?
    var notes: String?
    var strategyTags: [String] = []
    var followedPlan: Bool?
    var hadStopLossPlan: Bool?
    var chasedMove: Bool?
    var emotionalTrade: Bool?
    var reviewConclusion: String?
    var mistakeTags: [String] = []
    var createdAt: Date
    var ibkrExecutionId: String?
    var ibkrImported: Bool = false

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        ticker: String = "",
        direction: String = "买入",
        price: Double = 0.0,
        quantity: Int = 0,
        currency: String? = nil,
        entryReason: String? = nil,
        exitReason: String? = nil,
        emotion: String? = nil,
        pnl: Double? = nil,
        pnlPercent: Double? = nil,
        notes: String? = nil,
        strategyTags: [String] = [],
        followedPlan: Bool? = nil,
        hadStopLossPlan: Bool? = nil,
        chasedMove: Bool? = nil,
        emotionalTrade: Bool? = nil,
        reviewConclusion: String? = nil,
        mistakeTags: [String] = [],
        createdAt: Date = Date(),
        ibkrExecutionId: String? = nil,
        ibkrImported: Bool = false
    ) {
        self.id = id
        self.date = date
        self.ticker = ticker
        self.direction = direction
        self.price = price
        self.quantity = quantity
        self.currency = currency
        self.entryReason = entryReason
        self.exitReason = exitReason
        self.emotion = emotion
        self.pnl = pnl
        self.pnlPercent = pnlPercent
        self.notes = notes
        self.strategyTags = strategyTags
        self.followedPlan = followedPlan
        self.hadStopLossPlan = hadStopLossPlan
        self.chasedMove = chasedMove
        self.emotionalTrade = emotionalTrade
        self.reviewConclusion = reviewConclusion
        self.mistakeTags = mistakeTags
        self.createdAt = createdAt
        self.ibkrExecutionId = ibkrExecutionId
        self.ibkrImported = ibkrImported
    }

    var isEmpty: Bool {
        if ibkrImported { return false }
        return ticker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        price == 0 &&
        quantity == 0 &&
        entryReason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false &&
        exitReason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false &&
        emotion == nil &&
        pnl == nil &&
        pnlPercent == nil &&
        notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false &&
        strategyTags.isEmpty &&
        followedPlan == nil &&
        hadStopLossPlan == nil &&
        chasedMove == nil &&
        emotionalTrade == nil &&
        reviewConclusion?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false &&
        mistakeTags.isEmpty
    }

    func matchesSearch(_ searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }

        return ticker.lowercased().contains(query) ||
        direction.lowercased().contains(query) ||
        entryReason?.lowercased().contains(query) == true ||
        exitReason?.lowercased().contains(query) == true ||
        emotion?.lowercased().contains(query) == true ||
        notes?.lowercased().contains(query) == true ||
        reviewConclusion?.lowercased().contains(query) == true ||
        strategyTags.contains { $0.lowercased().contains(query) } ||
        mistakeTags.contains { $0.lowercased().contains(query) }
    }
}
