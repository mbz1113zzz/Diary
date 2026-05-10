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
    let averageWin: Double
    let averageLoss: Double
    let winningCount: Int
    let losingCount: Int

    var hasTrades: Bool {
        tradeCount > 0
    }

    var payoffRatio: Double {
        guard averageWin > 0, averageLoss < 0 else { return 0 }
        return averageWin / abs(averageLoss)
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

struct DailyPnLPoint: Identifiable {
    let date: Date
    let pnl: Double
    let cumulativePnl: Double
    let tradeCount: Int

    var id: Date { date }
}

struct SymbolPnLRow: Identifiable {
    let ticker: String
    let tradeCount: Int
    let pnl: Double

    var id: String { ticker }
}

enum TradeInsightTone {
    case positive
    case negative
    case warning
    case neutral
}

struct TradeInsight: Identifiable {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let tone: TradeInsightTone

    var id: String {
        "\(title)-\(value)-\(detail)"
    }
}

struct TagPerformanceRow: Identifiable {
    let tag: String
    let tradeCount: Int
    let recordedCount: Int
    let winningCount: Int
    let losingCount: Int
    let pnl: Double

    var id: String { tag }

    var winRate: Double {
        recordedCount == 0 ? 0 : Double(winningCount) / Double(recordedCount)
    }

    var averagePnl: Double {
        recordedCount == 0 ? 0 : pnl / Double(recordedCount)
    }
}

enum TradeAnalytics {
    static func summary(
        for period: TradeStatsPeriod,
        trades: [TradeEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TradeStatsSummary {
        let periodTrades = Self.trades(in: period, trades: trades, now: now, calendar: calendar)
        let pnlValues = periodTrades.compactMap { trade in
            trade.pnl.map { MoneyFormatters.convertedToHKD($0, from: MoneyFormatters.effectiveTradeCurrency(for: trade)) }
        }
        let pnlPercents = periodTrades.compactMap(\.pnlPercent)
        let winningCount = pnlValues.filter { $0 > 0 }.count
        let losingCount = pnlValues.filter { $0 < 0 }.count
        let wins = pnlValues.filter { $0 > 0 }
        let losses = pnlValues.filter { $0 < 0 }
        let winRate = pnlValues.isEmpty ? 0 : Double(winningCount) / Double(pnlValues.count)
        let averagePnlPercent = pnlPercents.isEmpty ? 0 : pnlPercents.reduce(0, +) / Double(pnlPercents.count)
        let averageWin = wins.isEmpty ? 0 : wins.reduce(0, +) / Double(wins.count)
        let averageLoss = losses.isEmpty ? 0 : losses.reduce(0, +) / Double(losses.count)

        return TradeStatsSummary(
            period: period,
            tradeCount: periodTrades.count,
            pnlTotal: pnlValues.reduce(0, +),
            winRate: winRate,
            averagePnlPercent: averagePnlPercent,
            averageWin: averageWin,
            averageLoss: averageLoss,
            winningCount: winningCount,
            losingCount: losingCount
        )
    }

    static func trades(
        in period: TradeStatsPeriod,
        trades: [TradeEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TradeEntry] {
        let interval = dateInterval(for: period, now: now, calendar: calendar)
        return trades.filter { interval.contains($0.date) }
    }

    static func dailyPnlSeries(
        for period: TradeStatsPeriod,
        trades: [TradeEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DailyPnLPoint] {
        let interval = dateInterval(for: period, now: now, calendar: calendar)
        let periodTrades = Self.trades(in: period, trades: trades, now: now, calendar: calendar)
        var grouped: [Date: (pnl: Double, tradeCount: Int)] = [:]

        for trade in periodTrades {
            let day = calendar.startOfDay(for: trade.date)
            let current = grouped[day] ?? (0, 0)
            let pnl = trade.pnl.map { MoneyFormatters.convertedToHKD($0, from: MoneyFormatters.effectiveTradeCurrency(for: trade)) } ?? 0
            grouped[day] = (current.pnl + pnl, current.tradeCount + 1)
        }

        let today = calendar.startOfDay(for: now)
        let intervalLastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
        let lastDay = min(today, calendar.startOfDay(for: intervalLastDay))
        var day = calendar.startOfDay(for: interval.start)
        var cumulativePnl = 0.0
        var points: [DailyPnLPoint] = []

        while day <= lastDay {
            let value = grouped[day] ?? (0, 0)
            cumulativePnl += value.pnl
            points.append(DailyPnLPoint(
                date: day,
                pnl: value.pnl,
                cumulativePnl: cumulativePnl,
                tradeCount: value.tradeCount
            ))

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        return points
    }

    static func symbolPnlRows(
        for period: TradeStatsPeriod,
        trades: [TradeEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [SymbolPnLRow] {
        let interval = dateInterval(for: period, now: now, calendar: calendar)
        var rows: [String: (tradeCount: Int, pnl: Double)] = [:]

        for trade in trades where interval.contains(trade.date) {
            let ticker = trade.ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !ticker.isEmpty else { continue }
            guard let rawPnl = trade.pnl else { continue }

            let pnl = MoneyFormatters.convertedToHKD(rawPnl, from: MoneyFormatters.effectiveTradeCurrency(for: trade))
            let current = rows[ticker] ?? (0, 0)
            rows[ticker] = (current.tradeCount + 1, current.pnl + pnl)
        }

        return rows
            .map { SymbolPnLRow(ticker: $0.key, tradeCount: $0.value.tradeCount, pnl: $0.value.pnl) }
            .sorted {
                let firstMagnitude = abs($0.pnl)
                let secondMagnitude = abs($1.pnl)
                if firstMagnitude == secondMagnitude {
                    return $0.ticker < $1.ticker
                }
                return firstMagnitude > secondMagnitude
            }
    }

    static func tagPerformanceRows(
        for period: TradeStatsPeriod,
        trades: [TradeEntry],
        keyPath: KeyPath<TradeEntry, [String]>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TagPerformanceRow] {
        let periodTrades = Self.trades(in: period, trades: trades, now: now, calendar: calendar)
        var rows: [String: (tradeCount: Int, recordedCount: Int, winningCount: Int, losingCount: Int, pnl: Double)] = [:]

        for trade in periodTrades {
            let tags = trade[keyPath: keyPath]
            guard !tags.isEmpty else { continue }

            let convertedPnl = trade.pnl.map {
                MoneyFormatters.convertedToHKD($0, from: MoneyFormatters.effectiveTradeCurrency(for: trade))
            }

            for tag in tags {
                let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanTag.isEmpty else { continue }

                var current = rows[cleanTag] ?? (0, 0, 0, 0, 0)
                current.tradeCount += 1

                if let convertedPnl {
                    current.recordedCount += 1
                    current.pnl += convertedPnl
                    if convertedPnl > 0 {
                        current.winningCount += 1
                    } else if convertedPnl < 0 {
                        current.losingCount += 1
                    }
                }

                rows[cleanTag] = current
            }
        }

        return rows
            .map {
                TagPerformanceRow(
                    tag: $0.key,
                    tradeCount: $0.value.tradeCount,
                    recordedCount: $0.value.recordedCount,
                    winningCount: $0.value.winningCount,
                    losingCount: $0.value.losingCount,
                    pnl: $0.value.pnl
                )
            }
            .sorted {
                if abs($0.pnl) == abs($1.pnl) {
                    return $0.tradeCount == $1.tradeCount ? $0.tag < $1.tag : $0.tradeCount > $1.tradeCount
                }
                return abs($0.pnl) > abs($1.pnl)
            }
    }

    static func insights(
        for period: TradeStatsPeriod,
        trades: [TradeEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TradeInsight] {
        let summary = Self.summary(for: period, trades: trades, now: now, calendar: calendar)
        guard summary.tradeCount > 0 else { return [] }

        let dailyPoints = Self.dailyPnlSeries(for: period, trades: trades, now: now, calendar: calendar)
            .filter { $0.tradeCount > 0 }
        let symbolRows = Self.symbolPnlRows(for: period, trades: trades, now: now, calendar: calendar)
        var insights: [TradeInsight] = []

        if let bestDay = dailyPoints.max(by: { $0.pnl < $1.pnl }), bestDay.pnl > 0 {
            insights.append(TradeInsight(
                title: "最佳交易日",
                value: MoneyFormatters.hkd(bestDay.pnl, signed: true),
                detail: "\(shortDate(bestDay.date, calendar: calendar))，\(bestDay.tradeCount) 笔交易贡献了本周期最高单日盈利。",
                icon: "sun.max",
                tone: .positive
            ))
        }

        if let worstDay = dailyPoints.min(by: { $0.pnl < $1.pnl }), worstDay.pnl < 0 {
            insights.append(TradeInsight(
                title: "需要复盘的日子",
                value: MoneyFormatters.hkd(worstDay.pnl, signed: true),
                detail: "\(shortDate(worstDay.date, calendar: calendar)) 是本周期最大单日亏损，适合回看当日入场和止损。",
                icon: "exclamationmark.triangle",
                tone: .negative
            ))
        }

        if let bestSymbol = symbolRows.max(by: { $0.pnl < $1.pnl }), bestSymbol.pnl > 0 {
            insights.append(TradeInsight(
                title: "主要盈利标的",
                value: bestSymbol.ticker,
                detail: "\(MoneyFormatters.hkd(bestSymbol.pnl, signed: true))，共 \(bestSymbol.tradeCount) 笔交易。",
                icon: "arrow.up.right.circle",
                tone: .positive
            ))
        }

        if let worstSymbol = symbolRows.min(by: { $0.pnl < $1.pnl }), worstSymbol.pnl < 0 {
            insights.append(TradeInsight(
                title: "主要拖累标的",
                value: worstSymbol.ticker,
                detail: "\(MoneyFormatters.hkd(worstSymbol.pnl, signed: true))，建议检查是否出现重复试错。",
                icon: "arrow.down.right.circle",
                tone: .negative
            ))
        }

        if let concentrationInsight = concentrationInsight(from: symbolRows) {
            insights.append(concentrationInsight)
        }

        if summary.pnlTotal < 0, summary.winRate >= 0.6 {
            insights.append(TradeInsight(
                title: "胜率不低但亏损",
                value: "\(String(format: "%.1f", summary.winRate * 100))%",
                detail: "平均亏损可能偏大，重点检查亏损交易是否及时退出。",
                icon: "scale.3d",
                tone: .warning
            ))
        } else if summary.pnlTotal > 0, summary.winRate <= 0.4 {
            insights.append(TradeInsight(
                title: "低胜率仍盈利",
                value: "\(String(format: "%.1f", summary.winRate * 100))%",
                detail: "盈亏比在保护结果，可以复盘盈利交易是否可复制。",
                icon: "sparkline",
                tone: .positive
            ))
        }

        return Array(insights.prefix(6))
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
                pnlTotal: current.pnlTotal + (trade.pnl.map { MoneyFormatters.convertedToHKD($0, from: MoneyFormatters.effectiveTradeCurrency(for: trade)) } ?? 0)
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

    private static func concentrationInsight(from rows: [SymbolPnLRow]) -> TradeInsight? {
        guard rows.count > 1 else { return nil }
        let absoluteTotal = rows.reduce(0) { $0 + abs($1.pnl) }
        guard absoluteTotal > 0, let topRow = rows.max(by: { abs($0.pnl) < abs($1.pnl) }) else { return nil }

        let share = abs(topRow.pnl) / absoluteTotal
        guard share >= 0.45 else { return nil }

        return TradeInsight(
            title: "盈亏集中度偏高",
            value: topRow.ticker,
            detail: "\(topRow.ticker) 占本周期标的盈亏波动的 \(String(format: "%.0f", share * 100))%，结果比较依赖单一标的。",
            icon: "scope",
            tone: .warning
        )
    }

    private static func shortDate(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day else { return "" }
        return "\(month)/\(day)"
    }
}
