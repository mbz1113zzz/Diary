import SwiftUI

#if os(macOS)
import AppKit
#endif

struct IBKRSettingsView: View {
    var syncManager: IBKRSyncManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage("ibkrGatewayURL") private var gatewayURL = "https://localhost:5000"
    @AppStorage("ibkrAutoSync") private var autoSync = true

    var body: some View {
        Section("IBKR 连接") {
            // 1. Connection status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                Spacer()
                Button("检测") {
                    Task { await syncManager.checkConnection() }
                }
            }

            // 2. Gateway URL
            TextField("Gateway URL", text: $gatewayURL)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif

            // 3. Auto sync toggle
            Toggle("启动时自动同步", isOn: $autoSync)

            // 4. Open in browser
            Button("在浏览器中登录") {
                guard let url = URL(string: gatewayURL) else { return }
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #else
                UIApplication.shared.open(url)
                #endif
            }

            // 5. Sync button
            Button {
                Task { await syncManager.manualSync(context: modelContext) }
            } label: {
                HStack {
                    Label("立即同步", systemImage: "arrow.triangle.2.circlepath")
                    if syncManager.isSyncing {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(syncManager.isSyncing)

            // 6. Last sync result
            if let result = syncManager.lastSyncResult {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(result.timestamp, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    + Text(" ")
                        .font(.caption)
                    + Text(result.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            Task { await syncManager.checkConnection() }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch syncManager.connectionStatus {
        case .connected: return .green
        case .notAuthenticated, .unreachable: return .red
        case .unknown: return .gray
        case .checking: return .orange
        }
    }

    private var statusText: String {
        switch syncManager.connectionStatus {
        case .connected: return "已连接"
        case .notAuthenticated: return "未认证"
        case .unreachable: return "无法连接"
        case .unknown: return "未知"
        case .checking: return "检测中..."
        }
    }
}
