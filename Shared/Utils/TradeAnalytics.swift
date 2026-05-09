import Foundation

enum TradeStatsPeriod: String, CaseIterable, Identifiable {
    case week = "本周"
    case month = "本月"

    var id: Self { self }
}

struct TradeStatsSummary {
    let period: TradeStatsPeriod
    let tradeCount: Int
    let pnlTotal: Double
    let winRate: Double
    let averagePnlPercent: Double
    let winningCount: Int
    let losingCount: Int

    var hasTrades: Bool {
        tradeCount > 0
    }
}

struct DailyRecordSummary: Identifiable {
    let date: Date
    let tradeCount: Int
    let diaryCount: Int
    let todoCount: Int
    let pnlTotal: Double

    var id: Date { date }

    var hasRecord: Bool {
        tradeCount > 0 || diaryCount > 0 || todoCount > 0
    }
}

enum TradeAnalytics {
    static func summary(
        for period: TradeStatsPeriod,
        trades: [TradeEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TradeStatsSummary {
        let interval = dateInterval(for: period, now: now, calendar: calendar)
        let periodTrades = trades.filter { interval.contains($0.date) }
        let pnlValues = periodTrades.compactMap(\.pnl)
        let pnlPercents = periodTrades.compactMap(\.pnlPercent)
        let winningCount = pnlValues.filter { $0 > 0 }.count
        let losingCount = pnlValues.filter { $0 < 0 }.count
        let winRate = pnlValues.isEmpty ? 0 : Double(winningCount) / Double(pnlValues.count)
        let averagePnlPercent = pnlPercents.isEmpty ? 0 : pnlPercents.reduce(0, +) / Double(pnlPercents.count)

        return TradeStatsSummary(
            period: period,
            tradeCount: periodTrades.count,
            pnlTotal: pnlValues.reduce(0, +),
            winRate: winRate,
            averagePnlPercent: averagePnlPercent,
            winningCount: winningCount,
            losingCount: losingCount
        )
    }

    static func dailySummaries(
        trades: [TradeEntry],
        diaries: [DiaryEntry],
        todos: [TodoItem],
        calendar: Calendar = .current
    ) -> [Date: DailyRecordSummary] {
        var summaries: [Date: DailyRecordSummary] = [:]

        for trade in trades {
            let day = calendar.startOfDay(for: trade.date)
            let current = summaries[day] ?? DailyRecordSummary(date: day, tradeCount: 0, diaryCount: 0, todoCount: 0, pnlTotal: 0)
            summaries[day] = DailyRecordSummary(
                date: day,
                tradeCount: current.tradeCount + 1,
                diaryCount: current.diaryCount,
                todoCount: current.todoCount,
                pnlTotal: current.pnlTotal + (trade.pnl ?? 0)
            )
        }

        for diary in diaries where !diary.isEmpty {
            let day = calendar.startOfDay(for: diary.date)
            let current = summaries[day] ?? DailyRecordSummary(date: day, tradeCount: 0, diaryCount: 0, todoCount: 0, pnlTotal: 0)
            summaries[day] = DailyRecordSummary(
                date: day,
                tradeCount: current.tradeCount,
                diaryCount: current.diaryCount + 1,
                todoCount: current.todoCount,
                pnlTotal: current.pnlTotal
            )
        }

        for todo in todos {
            let day = calendar.startOfDay(for: todo.date)
            let current = summaries[day] ?? DailyRecordSummary(date: day, tradeCount: 0, diaryCount: 0, todoCount: 0, pnlTotal: 0)
            summaries[day] = DailyRecordSummary(
                date: day,
                tradeCount: current.tradeCount,
                diaryCount: current.diaryCount,
                todoCount: current.todoCount + 1,
                pnlTotal: current.pnlTotal
            )
        }

        return summaries
    }

    private static func dateInterval(
        for period: TradeStatsPeriod,
        now: Date,
        calendar: Calendar
    ) -> DateInterval {
        let component: Calendar.Component = period == .week ? .weekOfYear : .month
        return calendar.dateInterval(of: component, for: now) ?? DateInterval(start: now, duration: 0)
    }
}
