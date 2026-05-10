import Foundation

/// Lightweight TWS socket client for snapshot market data.
/// Connects to TWS (default localhost:7496), requests snapshot prices, disconnects.
final class TWSService {

    private let host: String
    private let port: Int
    private let clientId: Int

    init(host: String = "localhost", port: Int = 7496, clientId: Int = 1) {
        self.host = host
        self.port = port
        self.clientId = clientId
    }

    /// Fetch snapshot market data for a list of tickers.
    /// Each ticker is requested as STK/SMART/USD by default.
    func fetchSnapshots(tickers: [String]) async throws -> [MarketSnapshot] {
        guard !tickers.isEmpty else { return [] }

        let socket = try await connect()
        defer { socket.close() }

        try await negotiateVersion(socket)

        var snapshots = [MarketSnapshot]()
        for (index, ticker) in tickers.enumerated() {
            if let snapshot = try? await requestSnapshot(socket, ticker: ticker, reqId: index + 1) {
                snapshots.append(snapshot)
            }
        }

        return snapshots
    }

    // MARK: - Socket

    private func connect() async throws -> Socket {
        let socket = Socket()
        try await socket.connect(host: host, port: port)
        return socket
    }

    private func negotiateVersion(_ socket: Socket) async throws {
        // Client version message: "API\0v100..157 <clientId>\0"
        let msg = "API\0v100..157 \(clientId)\0"
        try await socket.send(msg.data(using: .utf8)!)
        // Read server response (version + time)
        _ = try await socket.readUntilNull()
    }

    // MARK: - Market Data

    private func requestSnapshot(_ socket: Socket, ticker: String, reqId: Int) async throws -> MarketSnapshot {
        // reqMktData: id\0contract\0genericTicks\0snapshot\0regulatory\0
        // contract: conid\0symbol\0secType\0exchange\0primaryExchange\0currency\0
        let contract = "0\0\(ticker)\0STK\0SMART\0\0USD\0"
        let request = "\(reqId)\0\(contract)\0165,166\01\00\0"
        let msg = packMessage(type: "1", body: request)
        try await socket.send(msg)

        // Collect tick data for ~2 seconds
        let now = Date()
        var lastPrice = 0.0
        var change = 0.0
        var changePercent = 0.0

        while Date().timeIntervalSince(now) < 2.0 {
            guard let fields = try? await socket.readFields(timeout: 0.5) else { break }

            // Message types: 4=tickPrice, 45=tickGeneric
            if fields.count >= 3 {
                let msgType = fields[0]
                let tickReqId = Int(fields[1]) ?? -1
                guard tickReqId == reqId else { continue }

                let tickType = Int(fields[2]) ?? 0

                if msgType == "4", fields.count >= 4 {
                    let price = Double(fields[3]) ?? 0
                    switch tickType {
                    case 4: lastPrice = price       // Last
                    case 9: if lastPrice == 0 { lastPrice = price } // Close fallback
                    default: break
                    }
                } else if msgType == "45", fields.count >= 4 {
                    let value = Double(fields[3]) ?? 0
                    switch tickType {
                    case 165: change = value         // change
                    case 166: changePercent = value  // change %
                    default: break
                    }
                }
            }
        }

        // Cancel market data subscription
        let cancelMsg = packMessage(type: "2", body: "\(reqId)\0")
        try? await socket.send(cancelMsg)

        return MarketSnapshot(
            ticker: ticker,
            lastPrice: lastPrice,
            change: change,
            changePercent: changePercent / 100,
            timestamp: Date()
        )
    }

    // MARK: - Message helpers

    /// Pack a TWS API message: "type\0body\0"
    private func packMessage(type: String, body: String) -> Data {
        let raw = "\(type)\0\(body)"
        return raw.data(using: .utf8)!
    }
}

// MARK: - Raw Socket

private final class Socket {
    private var fd: Int32 = -1

    func connect(host: String, port: Int) async throws {
        fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw TWSServiceError.connectionFailed }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.s_addr = inet_addr(host)

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else {
            Darwin.close(fd)
            throw TWSServiceError.connectionFailed
        }
    }

    func send(_ data: Data) async throws {
        let result = data.withUnsafeBytes { ptr in
            Darwin.send(fd, ptr.baseAddress, data.count, 0)
        }
        guard result > 0 else { throw TWSServiceError.sendFailed }
    }

    func readUntilNull() async throws -> String {
        var buffer = [UInt8]()
        var byte: UInt8 = 0
        while true {
            let n = Darwin.recv(fd, &byte, 1, 0)
            if n <= 0 { throw TWSServiceError.receiveFailed }
            if byte == 0 { break }
            buffer.append(byte)
        }
        return String(bytes: buffer, encoding: .utf8) ?? ""
    }

    func readFields(timeout: TimeInterval) async throws -> [String] {
        var fields = [String]()
        var current = [UInt8]()
        var byte: UInt8 = 0
        let deadline = Date().timeIntervalSince1970 + timeout

        while true {
            let remaining = deadline - Date().timeIntervalSince1970
            if remaining <= 0 { break }

            // Non-blocking read
            let n = Darwin.recv(fd, &byte, 1, MSG_DONTWAIT)
            if n <= 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    continue
                }
                break
            }
            if byte == 0 {
                fields.append(String(bytes: current, encoding: .utf8) ?? "")
                // Check if complete message received (last field followed by extra null)
                continue
            }
            current.append(byte)
        }
        if !current.isEmpty {
            fields.append(String(bytes: current, encoding: .utf8) ?? "")
        }
        return fields
    }

    func close() {
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
    }

    deinit { close() }
}

enum TWSServiceError: Error {
    case connectionFailed
    case sendFailed
    case receiveFailed
}
