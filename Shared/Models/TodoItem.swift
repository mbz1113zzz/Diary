import Foundation
import SwiftData

@Model
final class TodoItem {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var date: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        isCompleted: Bool = false,
        date: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.date = date
        self.createdAt = createdAt
    }
}
