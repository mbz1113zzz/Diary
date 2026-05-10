import Foundation
import Network

/// TWS socket client for snapshot market data via NWConnection.
final class TWSService {

    private let host: String
    private let port: UInt16
    private let clientId: Int

    init(host: String = "127.0.0.1", port: Int = 7496, clientId: Int = 0) {
        self.host = host
        self.port = UInt16(port)
        self.clientId = clientId == 0 ? Int.random(in: 1000...9999) : clientId
    }

    func fetchSnapshots(tickers: [String]) async throws -> [MarketSnapshot] {
        guard !tickers.isEmpty else { return [] }

        let conn = try await connect()
        defer { conn.cancel() }

        try await negotiateVersion(on: conn)
        // Small delay for TWS to settle
        try await Task.sleep(nanoseconds: 200_000_000)

        var snapshots = [MarketSnapshot]()
        for (index, ticker) in tickers.enumerated() {
            let reqId = index + 1
            try await sendReqMktData(on: conn, ticker: ticker, reqId: reqId)

            if let snapshot = try? await readSnapshot(on: conn, ticker: ticker, reqId: reqId) {
                snapshots.append(snapshot)
            }

            // Cancel subscription
            try? await sendCancel(on: conn, reqId: reqId)
        }

        return snapshots
    }

    // MARK: - Connection

    private func connect() async throws -> NWConnection {
        let conn = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        return try await withCheckedThrowingContinuation { cont in
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready: cont.resume(returning: conn)
                case .failed(let err): cont.resume(throwing: err)
                default: break
                }
            }
            conn.start(queue: .global())
        }
    }

    private func negotiateVersion(on conn: NWConnection) async throws {
        // "API\0v<min>..<max> <clientId>\0"
        let msg = "API\0v100..180 \(clientId)\0"
        try await send(conn, msg)
        // Server replies: version\0time\0 — consume both
        _ = try await recvUntilNull(conn)
        _ = try await recvUntilNull(conn)
    }

    // MARK: - Market Data

    private func sendReqMktData(on conn: NWConnection, ticker: String, reqId: Int) async throws {
        // 15-field contract: conid\0symbol\0secType\0lastTradeDate\0strike\0right\0
        //   multiplier\0exchange\0primaryExchange\0currency\0localSymbol\0
        //   tradingClass\0includeExpired\0secIdType\0secId\0
        let contract = "0\0\(ticker)\0STK\0\00\0\0\0SMART\0\0USD\0\0\0\0\0\0"
        // reqMktData: reqId\0contract\0genericTicks\0snapshot\0regulatory\0
        let body = "\(reqId)\0\(contract)\0165,166\01\00\0"
        let raw = "1\0\(body)"
        try await send(conn, raw)
    }

    private func sendCancel(on conn: NWConnection, reqId: Int) async throws {
        let raw = "2\0\(reqId)\0"
        try await send(conn, raw)
    }

    private func readSnapshot(on conn: NWConnection, ticker: String, reqId: Int) async throws -> MarketSnapshot {
        var lastPrice = 0.0
        var change = 0.0
        var changePercent = 0.0
        let deadline = Date().timeIntervalSince1970 + 3.0

        while Date().timeIntervalSince1970 < deadline {
            let fields: [String]
            do {
                fields = try await recvFields(conn, timeout: 1.0)
            } catch {
                break
            }
            guard fields.count >= 3 else { continue }

            let msgType = fields[0]
            let msgReqId = Int(fields[1]) ?? -1

            // TWS error messages: type 4, id=reqId, errorCode, errorMsg
            if msgType == "4" && fields.count >= 4 && msgReqId == -1 {
                // Error from TWS — ignore for snapshot
                continue
            }

            guard msgReqId == reqId else { continue }
            let tickType = Int(fields[2]) ?? 0

            switch msgType {
            case "4": // tickPrice
                if fields.count >= 4 {
                    let price = Double(fields[3]) ?? 0
                    switch tickType {
                    case 4: lastPrice = price
                    default: break
                    }
                }
            case "5": // tickSize
                break
            case "6": // tickString
                break
            case "45": // tickGeneric
                if fields.count >= 4 {
                    let val = Double(fields[3]) ?? 0
                    switch tickType {
                    case 165: change = val
                    case 166: changePercent = val
                    default: break
                    }
                }
            default:
                break
            }
        }

        return MarketSnapshot(
            ticker: ticker,
            lastPrice: lastPrice,
            change: change,
            changePercent: changePercent / 100,
            timestamp: Date()
        )
    }

    // MARK: - NWConnection helpers

    private func send(_ conn: NWConnection, _ str: String) async throws {
        let data = str.data(using: .utf8)!
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { err in
                if let err { cont.resume(throwing: err) }
                else { cont.resume() }
            })
        }
    }

    private func recvUntilNull(_ conn: NWConnection) async throws -> String {
        var buf = Data()
        return try await withCheckedThrowingContinuation { cont in
            func readByte() {
                conn.receive(minimumIncompleteLength: 1, maximumLength: 1) { data, _, _, err in
                    if let err { cont.resume(throwing: err); return }
                    guard let data, let byte = data.first else { cont.resume(throwing: TWSServiceError.receiveFailed); return }
                    if byte == 0 {
                        cont.resume(returning: String(data: buf, encoding: .utf8) ?? "")
                    } else {
                        buf.append(byte)
                        readByte()
                    }
                }
            }
            readByte()
        }
    }

    private func recvFields(_ conn: NWConnection, timeout: TimeInterval) async throws -> [String] {
        var fields = [String]()
        var current = Data()
        let deadline = Date().timeIntervalSince1970 + timeout

        return try await withCheckedThrowingContinuation { cont in
            func readNext() {
                let remaining = deadline - Date().timeIntervalSince1970
                guard remaining > 0 else {
                    if !current.isEmpty { fields.append(String(data: current, encoding: .utf8) ?? "") }
                    cont.resume(returning: fields)
                    return
                }

                conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, err in
                    if let err {
                        // Ignore timeout/no-data errors, retry
                        let nsErr = err as NSError
                        if nsErr.domain == "NWErrorDomain" && nsErr.code == -65564 {
                            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { readNext() }
                            return
                        }
                        if !current.isEmpty { fields.append(String(data: current, encoding: .utf8) ?? "") }
                        cont.resume(returning: fields)
                        return
                    }
                    guard let data else {
                        if !current.isEmpty { fields.append(String(data: current, encoding: .utf8) ?? "") }
                        cont.resume(returning: fields)
                        return
                    }
                    for byte in data {
                        if byte == 0 {
                            fields.append(String(data: current, encoding: .utf8) ?? "")
                            current = Data()
                        } else {
                            current.append(byte)
                        }
                    }
                    readNext()
                }
            }
            readNext()
        }
    }
}

enum TWSServiceError: Error {
    case connectionFailed
    case receiveFailed
}
