import Foundation
import SwiftData
import Observation

@Observable
final class IBKRSyncManager {

    // MARK: - Nested Types

    struct SyncResult {
        let newCount: Int
        let message: String
        let timestamp: Date
    }

    // MARK: - Properties

    var isSyncing = false
    var lastSyncResult: SyncResult?
    var isConfigured: Bool {
        let token = UserDefaults.standard.string(forKey: "ibkrFlexToken") ?? ""
        let queryId = UserDefaults.standard.string(forKey: "ibkrFlexQueryId") ?? ""
        return !token.isEmpty && !queryId.isEmpty
    }

    private let service: IBKRService

    // MARK: - Init

    init(service: IBKRService = IBKRService()) {
        self.service = service
    }

    // MARK: - Sync

    func manualSync(context: ModelContext) async {
        let token = UserDefaults.standard.string(forKey: "ibkrFlexToken") ?? ""
        let queryId = UserDefaults.standard.string(forKey: "ibkrFlexQueryId") ?? ""

        guard !token.isEmpty, !queryId.isEmpty else {
            await MainActor.run {
                lastSyncResult = SyncResult(newCount: 0, message: "请先在设置中填写 Flex Token 和 Query ID", timestamp: Date())
                isSyncing = false
            }
            return
        }

        await MainActor.run { isSyncing = true }

        do {
            let trades = try await service.fetchTrades(token: token, queryId: queryId)
            let newCount = importTrades(trades, context: context)
            let message = newCount > 0 ? "导入了 \(newCount) 笔新交易" : "没有新交易"
            await MainActor.run {
                lastSyncResult = SyncResult(newCount: newCount, message: message, timestamp: Date())
                isSyncing = false
            }
        } catch {
            await MainActor.run {
                lastSyncResult = SyncResult(newCount: 0, message: "同步失败: \(error.localizedDescription)", timestamp: Date())
                isSyncing = false
            }
        }
    }

    func autoSync(context: ModelContext) async {
        let autoSyncEnabled = UserDefaults.standard.object(forKey: "ibkrAutoSync") as? Bool ?? true
        guard autoSyncEnabled, isConfigured else { return }

        await manualSync(context: context)
    }

    // MARK: - Import

    private func importTrades(_ flexTrades: [FlexTrade], context: ModelContext) -> Int {
        // Fetch existing execution IDs to deduplicate
        var descriptor = FetchDescriptor<TradeEntry>()
        descriptor.predicate = #Predicate<TradeEntry> { $0.ibkrExecutionId != nil }

        let existingTrades = (try? context.fetch(descriptor)) ?? []
        let existingIds = Set(existingTrades.compactMap { $0.ibkrExecutionId })

        // Filter to only new trades, skip currency conversions (e.g. USD.HKD, USD.TWD)
        let newTrades = flexTrades.filter { trade in
            !existingIds.contains(trade.tradeId) && !trade.symbol.contains(".")
        }

        for trade in newTrades {
            // Parse date
            let tradeDate = IBKRService.flexDateFormatter.date(from: trade.dateTime)
                ?? IBKRService.flexDateOnlyFormatter.date(from: trade.dateTime)
                ?? Date()

            let pnlValue = Double(trade.realizedPnl ?? "0") ?? 0

            // Map buySell: "BUY" → "买入", "SELL" → "卖出"
            let direction: String
            switch trade.buySell.uppercased() {
            case "BUY", "BOT":
                direction = "买入"
            case "SELL", "SLD":
                direction = "卖出"
            default:
                direction = trade.buySell
            }

            let entry = TradeEntry(
                date: Calendar.current.startOfDay(for: tradeDate),
                ticker: trade.symbol,
                direction: direction,
                price: Double(trade.price) ?? 0,
                quantity: abs(Int(Double(trade.quantity) ?? 0)),
                currency: MoneyFormatters.effectiveTradeCurrency(
                    ticker: trade.symbol,
                    reportedCurrency: trade.currency,
                    exchange: trade.exchange,
                    isIBKRImported: true
                ),
                pnl: pnlValue == 0 ? nil : pnlValue,
                ibkrExecutionId: trade.tradeId,
                ibkrImported: true
            )
            context.insert(entry)
        }

        // Save last sync time
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "ibkrLastSyncTime")

        return newTrades.count
    }
}
