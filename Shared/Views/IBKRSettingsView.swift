import SwiftUI

struct IBKRSettingsView: View {
    var syncManager: IBKRSyncManager
    @Environment(\.modelContext) private var modelContext
    @State private var flexToken: String = KeychainHelper.read(key: "ibkrFlexToken") ?? ""
    @AppStorage("ibkrFlexQueryId") private var flexQueryId = ""
    @AppStorage("ibkrAutoSync") private var autoSync = true
    @AppStorage("ibkrGatewayHost") private var gatewayHost = "localhost"
    @AppStorage("ibkrGatewayPort") private var gatewayPort = 5000

    var body: some View {
        Section("IBKR 交易同步") {
            // Status
            HStack {
                Circle()
                    .fill(syncManager.isConfigured ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text(syncManager.isConfigured ? "已配置" : "未配置")
                    .font(.subheadline)
            }

            // Token input (stored in Keychain)
            SecureField("Flex Token", text: $flexToken)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .onChange(of: flexToken) { _, newValue in
                    if newValue.isEmpty {
                        KeychainHelper.delete(key: "ibkrFlexToken")
                    } else {
                        KeychainHelper.save(key: "ibkrFlexToken", value: newValue)
                    }
                }

            // Query ID input
            TextField("Flex Query ID", text: $flexQueryId)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.numberPad)
                #endif

            // Auto sync toggle
            Toggle("启动时自动同步", isOn: $autoSync)
        }

        Section("行情数据") {
            HStack {
                Text("Gateway Host")
                Spacer()
                TextField("localhost", text: $gatewayHost)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 160)
            }
            HStack {
                Text("Gateway Port")
                Spacer()
                TextField("5000", value: $gatewayPort, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
            }
            Text("需要 IBKR Client Portal Gateway 运行中才能获取实时行情。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section {
            // Help link
            Button("如何获取 Token 和 Query ID？") {
                let url = URL(string: "https://www.interactivebrokers.com/en/software/am3/am/reports/activityflexqueries.htm")!
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #else
                UIApplication.shared.open(url)
                #endif
            }
            .font(.caption)

            // Sync button
            Button {
                Task { await syncManager.manualSync(context: modelContext) }
            } label: {
                HStack {
                    Label("立即同步", systemImage: "arrow.triangle.2.circlepath")
                    if syncManager.isSyncing {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(syncManager.isSyncing || !syncManager.isConfigured)

            // Last sync result
            if let result = syncManager.lastSyncResult {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.message)
                        .font(.caption)
                        .foregroundStyle(result.newCount > 0 ? .primary : .secondary)
                    Text(result.timestamp, format: .dateTime.month().day().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#if os(macOS)
import AppKit
#endif
