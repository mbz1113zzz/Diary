import Foundation
import SwiftData
import SwiftUI

@Observable
final class DiaryViewModel {
    var selectedDate: Date = Date()

    var selectedDayStart: Date {
        DateFormatters.startOfDay(selectedDate)
    }

    var selectedDayEnd: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: selectedDayStart)!
    }

    func findOrCreateDiaryEntry(for date: Date, in context: ModelContext) -> DiaryEntry {
        let dayStart = DateFormatters.startOfDay(date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!

        let predicate = #Predicate<DiaryEntry> { entry in
            entry.date >= dayStart && entry.date < dayEnd
        }
        let descriptor = FetchDescriptor<DiaryEntry>(predicate: predicate)

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let newEntry = DiaryEntry(date: dayStart)
        context.insert(newEntry)
        return newEntry
    }

    func createTradeEntry(for date: Date, in context: ModelContext) -> TradeEntry {
        let trade = TradeEntry(date: DateFormatters.startOfDay(date))
        context.insert(trade)
        return trade
    }

    func tradeCount(for date: Date, in context: ModelContext) -> Int {
        let dayStart = DateFormatters.startOfDay(date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        let predicate = #Predicate<TradeEntry> { trade in
            trade.date >= dayStart && trade.date < dayEnd
        }
        let descriptor = FetchDescriptor<TradeEntry>(predicate: predicate)
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func cleanupEmptyDiaryIfNeeded(_ entry: DiaryEntry?, in context: ModelContext) -> DiaryEntry? {
        guard let entry, entry.isEmpty else { return entry }
        context.delete(entry)
        return nil
    }

    static func findOrCreateDiaryEntry(for date: Date, in context: ModelContext) -> DiaryEntry {
        let dayStart = DateFormatters.startOfDay(date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!

        let predicate = #Predicate<DiaryEntry> { entry in
            entry.date >= dayStart && entry.date < dayEnd
        }
        let descriptor = FetchDescriptor<DiaryEntry>(predicate: predicate)

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let newEntry = DiaryEntry(date: dayStart)
        context.insert(newEntry)
        return newEntry
    }

    static func cleanupEmptyDiaryIfNeeded(_ entry: DiaryEntry?, in context: ModelContext) -> DiaryEntry? {
        guard let entry, entry.isEmpty else { return entry }
        context.delete(entry)
        return nil
    }

    func todoProgress(for date: Date, in context: ModelContext) -> (completed: Int, total: Int) {
        let dayStart = DateFormatters.startOfDay(date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        let predicate = #Predicate<TodoItem> { todo in
            todo.date >= dayStart && todo.date < dayEnd
        }
        let descriptor = FetchDescriptor<TodoItem>(predicate: predicate)
        guard let todos = try? context.fetch(descriptor) else { return (0, 0) }
        return (todos.filter(\.isCompleted).count, todos.count)
    }
}
