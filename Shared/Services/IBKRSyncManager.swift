import Foundation
import SwiftData
import Observation

@Observable
final class IBKRSyncManager {

    // MARK: - Nested Types

    enum ConnectionStatus {
        case unknown, checking, connected, notAuthenticated, unreachable
    }

    struct SyncResult {
        let newCount: Int
        let message: String
        let timestamp: Date
    }

    // MARK: - Properties

    var isSyncing = false
    var lastSyncResult: SyncResult?
    var connectionStatus: ConnectionStatus = .unknown

    private let service: IBKRService
    private var keepAliveTask: Task<Void, Never>?

    // MARK: - Init

    init(service: IBKRService? = nil) {
        if let service {
            self.service = service
        } else {
            let gatewayURL = UserDefaults.standard.string(forKey: "ibkrGatewayURL") ?? "https://localhost:5000"
            self.service = IBKRService(baseURL: gatewayURL)
        }
    }

    // MARK: - Connection

    func checkConnection() async {
        await MainActor.run { connectionStatus = .checking }
        do {
            let status = try await service.checkAuthStatus()
            if status.authenticated {
                await MainActor.run { connectionStatus = .connected }
                startKeepAlive()
            } else {
                await MainActor.run { connectionStatus = .notAuthenticated }
                stopKeepAlive()
            }
        } catch {
            await MainActor.run { connectionStatus = .unreachable }
            stopKeepAlive()
        }
    }

    // MARK: - Sync

    func manualSync(context: ModelContext) async {
        await MainActor.run { isSyncing = true }

        await checkConnection()

        guard connectionStatus == .connected else {
            let message: String
            switch connectionStatus {
            case .notAuthenticated:
                message = "IBKR 网关未认证，请在浏览器中完成登录"
            case .unreachable:
                message = "无法连接到 IBKR 网关，请确认 Client Portal Gateway 正在运行"
            default:
                message = "连接状态未知，请重试"
            }
            await MainActor.run {
                lastSyncResult = SyncResult(newCount: 0, message: message, timestamp: Date())
                isSyncing = false
            }
            return
        }

        do {
            let trades = try await service.fetchTrades()
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
        guard autoSyncEnabled else { return }

        await checkConnection()
        guard connectionStatus == .connected else { return }

        do {
            let trades = try await service.fetchTrades()
            let newCount = importTrades(trades, context: context)
            let message = newCount > 0 ? "自动导入了 \(newCount) 笔新交易" : "没有新交易"
            await MainActor.run {
                lastSyncResult = SyncResult(newCount: newCount, message: message, timestamp: Date())
            }
        } catch {
            // Auto sync silently ignores errors
        }
    }

    // MARK: - Import

    private func importTrades(_ ibkrTrades: [IBKRTrade], context: ModelContext) -> Int {
        // Fetch existing execution IDs to deduplicate
        var descriptor = FetchDescriptor<TradeEntry>()
        descriptor.predicate = #Predicate<TradeEntry> { $0.ibkrExecutionId != nil }

        let existingTrades = (try? context.fetch(descriptor)) ?? []
        let existingIds = Set(existingTrades.compactMap { $0.ibkrExecutionId })

        // Filter to only new trades
        let newTrades = ibkrTrades.filter { !existingIds.contains($0.executionId) }

        for trade in newTrades {
            let tradeDate = IBKRService.tradeTimeDateFormatter.date(from: trade.tradeTime) ?? Date()
            let pnlValue = Double(trade.realizedPnl ?? "0") ?? 0

            let entry = TradeEntry(
                date: tradeDate,
                ticker: trade.symbol,
                direction: trade.side == "BOT" ? "买入" : "卖出",
                price: Double(trade.price) ?? 0,
                quantity: abs(Int(trade.size) ?? 0),
                pnl: pnlValue == 0 ? nil : pnlValue,
                ibkrExecutionId: trade.executionId,
                ibkrImported: true
            )
            context.insert(entry)
        }

        // Save last sync time
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "ibkrLastSyncTime")

        return newTrades.count
    }

    // MARK: - Keep Alive

    func startKeepAlive() {
        stopKeepAlive()
        keepAliveTask = Task {
            while !Task.isCancelled {
                try? await service.tickle()
                try? await Task.sleep(for: .seconds(55))
            }
        }
    }

    func stopKeepAlive() {
        keepAliveTask?.cancel()
        keepAliveTask = nil
    }
}
