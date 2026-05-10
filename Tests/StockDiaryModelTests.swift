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

    func testIBKRTaiwanTickerUsesTWDForLegacyImportedTrades() {
        let trade = TradeEntry(
            ticker: "6830",
            price: 100,
            quantity: 1,
            currency: "HKD",
            pnl: 100,
            ibkrImported: true
        )

        XCTAssertEqual(MoneyFormatters.effectiveTradeCurrency(for: trade), "TWD")
        XCTAssertEqual(MoneyFormatters.convertedToHKD(100, from: MoneyFormatters.effectiveTradeCurrency(for: trade)), 24.9)
    }

    func testIBKRTaiwanExchangeOverridesReportedCurrency() {
        let currency = MoneyFormatters.effectiveTradeCurrency(
            ticker: "6830",
            reportedCurrency: "HKD",
            exchange: "TWSE",
            isIBKRImported: true
        )

        XCTAssertEqual(currency, "TWD")
    }

    func testIBKRUSTickersUseUSDForLegacyImportedTrades() {
        let tickers = ["TSLA", "INTC", "DRAM", "EOSE 260515C00007500"]

        for ticker in tickers {
            let trade = TradeEntry(
                ticker: ticker,
                price: 100,
                quantity: 1,
                currency: "HKD",
                ibkrImported: true
            )

            XCTAssertEqual(MoneyFormatters.effectiveTradeCurrency(for: trade), "USD", ticker)
        }
    }

    func testManualTickerKeepsExplicitCurrency() {
        let trade = TradeEntry(
            ticker: "TSLA",
            price: 100,
            quantity: 1,
            currency: "HKD",
            ibkrImported: false
        )

        XCTAssertEqual(MoneyFormatters.effectiveTradeCurrency(for: trade), "HKD")
    }

    func testMarkdownSyntaxParserRecognizesTaskListsAndTables() {
        let markdown = """
        - [x] 已复盘
        - [ ] 等待记录

        | 标的 | 结果 |
        | --- | --- |
        | AAPL | 盈利 |
        """

        let spans = MarkdownSyntaxParser.spans(in: markdown)

        XCTAssertTrue(spans.contains { $0.kind == .listItem(checkbox: .checked) })
        XCTAssertTrue(spans.contains { $0.kind == .listItem(checkbox: .unchecked) })
        XCTAssertTrue(spans.contains { $0.kind == .table })
    }

    func testMarkdownReturnContinuesListItems() throws {
        let text = "- 第一项"
        let result = try XCTUnwrap(MarkdownEditing.returnContinuation(
            in: text,
            selectedRange: NSRange(location: (text as NSString).length, length: 0)
        ))

        XCTAssertEqual(result.text, "- 第一项\n- ")
    }

    func testMarkdownReturnExitsEmptyTaskItem() throws {
        let text = "- [ ] "
        let result = try XCTUnwrap(MarkdownEditing.returnContinuation(
            in: text,
            selectedRange: NSRange(location: (text as NSString).length, length: 0)
        ))

        XCTAssertEqual(result.text, "")
        XCTAssertEqual(result.selectedRange.location, 0)
    }

    func testMarkdownTabIndentsAndOutdentsListItem() throws {
        let text = "- 第一项"
        let indented = try XCTUnwrap(MarkdownEditing.indentListItem(
            in: text,
            selectedRange: NSRange(location: 2, length: 0)
        ))

        XCTAssertEqual(indented.text, "    - 第一项")
        XCTAssertEqual(indented.selectedRange.location, 6)

        let outdented = try XCTUnwrap(MarkdownEditing.outdentListItem(
            in: indented.text,
            selectedRange: indented.selectedRange
        ))

        XCTAssertEqual(outdented.text, text)
        XCTAssertEqual(outdented.selectedRange.location, 2)
    }

    #if os(macOS)
    func testMarkdownHighlighterDrawsInactiveUnorderedListMarkerAsBullet() throws {
        let storage = NSMutableAttributedString(string: "- dad")

        MarkdownHighlighter.highlight(storage, activeLineRange: nil)

        XCTAssertNotNil(storage.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment)
    }
    #endif

    #if os(macOS)
    func testMarkerIndexesForHeading() {
        let storage = NSMutableAttributedString(string: "## Hello")
        let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: nil)

        // "## " = characters 0, 1, 2 should be markers
        XCTAssertTrue(indexes.contains(0))
        XCTAssertTrue(indexes.contains(1))
        XCTAssertTrue(indexes.contains(2))
        // "Hello" characters should NOT be markers
        XCTAssertFalse(indexes.contains(3))
        XCTAssertFalse(indexes.contains(4))
    }
    #endif

    #if os(macOS)
    func testMarkerIndexesForBoldAndItalic() {
        let text = "**bold** and *italic*"
        let storage = NSMutableAttributedString(string: text)
        let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: nil)

        XCTAssertTrue(indexes.contains(0))
        XCTAssertTrue(indexes.contains(1))
        XCTAssertTrue(indexes.contains(6))
        XCTAssertTrue(indexes.contains(7))
        XCTAssertTrue(indexes.contains(13))
        XCTAssertTrue(indexes.contains(20))
        XCTAssertFalse(indexes.contains(2))
        XCTAssertFalse(indexes.contains(14))
    }

    func testMarkerIndexesForInlineCode() {
        let text = "use `code` here"
        let storage = NSMutableAttributedString(string: text)
        let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: nil)

        XCTAssertTrue(indexes.contains(4))
        XCTAssertTrue(indexes.contains(9))
        XCTAssertFalse(indexes.contains(5))
    }

    func testMarkerIndexesForLink() {
        let text = "[click](https://example.com)"
        let storage = NSMutableAttributedString(string: text)
        let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: nil)

        XCTAssertTrue(indexes.contains(0))
        XCTAssertTrue(indexes.contains(6))
        XCTAssertTrue(indexes.contains(7))
        XCTAssertTrue(indexes.contains(27))
        XCTAssertFalse(indexes.contains(1))
        XCTAssertFalse(indexes.contains(5))
    }

    func testMarkerIndexesForStrikethrough() {
        let text = "~~deleted~~"
        let storage = NSMutableAttributedString(string: text)
        let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: nil)

        XCTAssertTrue(indexes.contains(0))
        XCTAssertTrue(indexes.contains(1))
        XCTAssertTrue(indexes.contains(9))
        XCTAssertTrue(indexes.contains(10))
        XCTAssertFalse(indexes.contains(2))
    }

    func testMarkerIndexesForUnorderedList() {
        let text = "- item"
        let storage = NSMutableAttributedString(string: text)
        let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: nil)

        XCTAssertTrue(indexes.contains(0))
        XCTAssertFalse(indexes.contains(2))
    }

    func testActiveLineExcludesMarkersFromHiding() {
        let text = "## Hello"
        let storage = NSMutableAttributedString(string: text)
        let activeRange = NSRange(location: 0, length: (text as NSString).length)
        let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: activeRange)

        XCTAssertTrue(indexes.contains(0))
        XCTAssertTrue(indexes.contains(1))
        XCTAssertTrue(indexes.contains(2))
    }
    #endif
}
