import Foundation
import SwiftData

@Model
final class MemoEntry {
    var id: UUID
    var title: String
    @Attribute(.externalStorage) var richTextData: Data?
    var plainText: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        richTextData: Data? = nil,
        plainText: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.richTextData = richTextData
        self.plainText = plainText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        let firstLine = plainText
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstLine.isEmpty ? "未命名随记" : firstLine
    }

    var previewText: String {
        let trimmedText = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? "开始写一点什么..." : trimmedText
    }
}
