import Foundation

// MARK: - Response Models

struct IBKRAuthStatus: Codable {
    let authenticated: Bool
    let competing: Bool
    let connected: Bool
}

struct IBKRAccount: Codable {
    let id: String
    let accountId: String
    let accountTitle: String?
    let type: String?
}

struct IBKRTrade: Codable {
    let executionId: String
    let symbol: String
    let side: String
    let price: String
    let size: String
    let tradeTime: String
    let netAmount: Double?
    let account: String?
    let exchange: String?
    let realizedPnl: String?
    let conid: Int?

    enum CodingKeys: String, CodingKey {
        case executionId = "execution_id"
        case symbol
        case side
        case price
        case size
        case tradeTime = "trade_time"
        case netAmount = "net_amount"
        case account
        case exchange
        case realizedPnl = "realized_pnl"
        case conid
    }
}

// MARK: - Error

enum IBKRError: LocalizedError {
    case gatewayUnreachable
    case notAuthenticated
    case decodingFailed
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .gatewayUnreachable:
            return "无法连接到 IBKR 网关，请确认 Client Portal Gateway 正在运行"
        case .notAuthenticated:
            return "IBKR 网关未认证，请在浏览器中完成登录"
        case .decodingFailed:
            return "解析 IBKR 响应数据失败"
        case .httpError(let code):
            return "IBKR 请求失败，HTTP 状态码: \(code)"
        }
    }
}

// MARK: - Session Delegate

class IBKRSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.host == "localhost",
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - Service

final class IBKRService {

    let baseURL: String
    let session: URLSession

    /// DateFormatter for IBKR trade time format: "yyyyMMdd-HH:mm:ss"
    static let tradeTimeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        return formatter
    }()

    init(baseURL: String = "https://localhost:5000") {
        self.baseURL = baseURL
        let delegate = IBKRSessionDelegate()
        let configuration = URLSessionConfiguration.default
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    // MARK: - Auth

    /// GET /v1/api/iserver/auth/status
    func checkAuthStatus() async throws -> IBKRAuthStatus {
        let data = try await get(path: "/v1/api/iserver/auth/status")
        return try decode(IBKRAuthStatus.self, from: data)
    }

    // MARK: - Accounts

    /// GET /v1/api/portfolio/accounts
    func fetchAccounts() async throws -> [IBKRAccount] {
        let data = try await get(path: "/v1/api/portfolio/accounts")
        return try decode([IBKRAccount].self, from: data)
    }

    // MARK: - Trades

    /// GET /v1/api/iserver/account/trades
    func fetchTrades() async throws -> [IBKRTrade] {
        let data = try await get(path: "/v1/api/iserver/account/trades")
        return try decode([IBKRTrade].self, from: data)
    }

    // MARK: - Tickle

    /// POST /v1/api/tickle — keep session alive
    func tickle() async throws {
        let url = URL(string: baseURL + "/v1/api/tickle")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                throw IBKRError.httpError(httpResponse.statusCode)
            }
        } catch let error as IBKRError {
            throw error
        } catch {
            throw IBKRError.gatewayUnreachable
        }
    }

    // MARK: - Private Helpers

    private func get(path: String) async throws -> Data {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw IBKRError.gatewayUnreachable
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IBKRError.gatewayUnreachable
        }
        if httpResponse.statusCode == 401 {
            throw IBKRError.notAuthenticated
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw IBKRError.httpError(httpResponse.statusCode)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw IBKRError.decodingFailed
        }
    }
}
