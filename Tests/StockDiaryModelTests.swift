import XCTest
@testable import StockDiary

final class StockDiaryModelTests: XCTestCase {
    func testDiaryEntryIsEmptyUntilUserAddsContent() {
        let entry = DiaryEntry(content: "   ")

        XCTAssertTrue(entry.isEmpty)

        entry.mood = "😊"

        XCTAssertFalse(entry.isEmpty)
    }

    func testTradeEntryIsEmptyUntilUserAddsTradeDetails() {
        let trade = TradeEntry()

        XCTAssertTrue(trade.isEmpty)

        trade.mistakeTags = ["FOMO"]

        XCTAssertFalse(trade.isEmpty)
    }

    func testTradeEntryReviewTemplateMakesEntryNonEmpty() {
        let trade = TradeEntry()

        XCTAssertTrue(trade.isEmpty)

        trade.followedPlan = false
        trade.reviewConclusion = "没有等确认，下一次降低仓位。"

        XCTAssertFalse(trade.isEmpty)
    }

    func testTradeStatsSummaryCalculatesPeriodMetrics() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 9)))
        let winDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 8)))
        let lossDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 9)))
        let outsideDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 1)))
        let trades = [
            TradeEntry(date: winDate, ticker: "AAPL", pnl: 120, pnlPercent: 6),
            TradeEntry(date: lossDate, ticker: "MSFT", pnl: -40, pnlPercent: -2),
            TradeEntry(date: outsideDate, ticker: "TSLA", pnl: 500, pnlPercent: 20)
        ]

        let summary = TradeAnalytics.summary(for: .month, trades: trades, now: now, calendar: calendar)

        XCTAssertEqual(summary.tradeCount, 2)
        XCTAssertEqual(summary.pnlTotal, 80)
        XCTAssertEqual(summary.winRate, 0.5)
        XCTAssertEqual(summary.averagePnlPercent, 2)
    }

    func testTradeExportIncludesStrategyTags() {
        let trade = TradeEntry(
            ticker: "AAPL",
            direction: "买入",
            price: 180,
            quantity: 10,
            pnl: 20,
            strategyTags: ["突破", "事件驱动"],
            followedPlan: true,
            hadStopLossPlan: true,
            chasedMove: false,
            emotionalTrade: false,
            reviewConclusion: "执行符合计划",
            mistakeTags: ["没等确认"]
        )

        let csv = TradeExportBuilder.csv(for: [trade])

        XCTAssertTrue(csv.contains("AAPL"))
        XCTAssertTrue(csv.contains("突破|事件驱动"))
        XCTAssertTrue(csv.contains("执行符合计划"))
        XCTAssertTrue(csv.contains("没等确认"))
    }

    func testStartOfDayNormalizesDate() throws {
        let components = DateComponents(
            calendar: Calendar.current,
            year: 2026,
            month: 5,
            day: 9,
            hour: 22,
            minute: 30
        )
        let date = try XCTUnwrap(components.date)

        XCTAssertEqual(DateFormatters.startOfDay(date), Calendar.current.startOfDay(for: date))
    }
}
