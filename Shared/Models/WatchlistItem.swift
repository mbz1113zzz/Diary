import Foundation
import SwiftData

@Model
final class WatchlistItem {
    var id: UUID
    var ticker: String
    var displayName: String
    var groupTag: String
    var sortOrder: Int
    var createdAt: Date

    init(
        ticker: String,
        displayName: String = "",
        groupTag: String = "默认",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.ticker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.groupTag = groupTag.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
