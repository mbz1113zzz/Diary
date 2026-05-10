import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\WatchlistItem.sortOrder), SortDescriptor(\WatchlistItem.createdAt)])
    private var items: [WatchlistItem]

    @State private var snapshots: [String: MarketSnapshot] = [:]
    @State private var isLoadingQuotes = false
    @State private var marketStatus: String?
    @State private var showingAddSheet = false

    private let service = IBKRService()

    private var groupTags: [String] {
        var seen = Set<String>()
        return items.compactMap { item in
            seen.insert(item.groupTag).inserted ? item.groupTag : nil
        }
    }

    private func items(for tag: String) -> [WatchlistItem] {
        items.filter { $0.groupTag == tag }
    }

    var body: some View {
        MascotCornerContainer {
            if items.isEmpty {
                ContentUnavailableView(
                    "还没有自选股",
                    systemImage: "star",
                    description: Text("点击右上角 + 添加关注的股票")
                )
                .frame(maxWidth: .infinity, minHeight: 320)
            } else {
                List {
                    ForEach(groupTags, id: \.self) { tag in
                        Section(tag) {
                            ForEach(items(for: tag)) { item in
                                WatchlistRow(item: item, snapshot: snapshots[item.ticker])
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    modelContext.delete(items(for: tag)[index])
                                }
                                try? modelContext.save()
                            }
                        }
                    }
                }
                #if os(macOS)
                .listStyle(.inset)
                #endif
            }
        }
        .navigationTitle("自选")
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await refreshQuotes() }
                } label: {
                    if isLoadingQuotes {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("刷新行情", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(isLoadingQuotes)
            }
            ToolbarItem {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("添加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddWatchlistSheetView()
        }
        .overlay(alignment: .bottom) {
            if let marketStatus {
                Text(marketStatus)
                    .font(.caption)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 8)
            }
        }
    }

    @MainActor
    private func refreshQuotes() async {
        isLoadingQuotes = true
        marketStatus = nil

        let tickers = items.map { $0.ticker }
        guard !tickers.isEmpty else {
            isLoadingQuotes = false
            return
        }

        do {
            let host = UserDefaults.standard.string(forKey: "ibkrTWSHost") ?? "localhost"
            let port = UserDefaults.standard.integer(forKey: "ibkrTWSPort")
            let effectivePort = port > 0 ? port : 7496
            let result = try await service.fetchMarketSnapshots(tickers: tickers, host: host, port: effectivePort)
            var dict = [String: MarketSnapshot]()
            for snapshot in result {
                dict[snapshot.ticker] = snapshot
            }
            snapshots = dict
        } catch {
            marketStatus = "行情不可用：\(error.localizedDescription)"
        }

        isLoadingQuotes = false
    }
}

struct WatchlistRow: View {
    let item: WatchlistItem
    let snapshot: MarketSnapshot?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.ticker)
                    .font(.subheadline.weight(.semibold))
                if !item.displayName.isEmpty {
                    Text(item.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let snapshot {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f", snapshot.lastPrice))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Text(MoneyFormatters.signedPercentage(snapshot.changePercent))
                        .font(.caption)
                        .foregroundStyle(Color.pnl(snapshot.change))
                        .monospacedDigit()
                }
            } else {
                Text("--")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddWatchlistSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var ticker = ""
    @State private var displayName = ""
    @State private var groupTag = "默认"
    @State private var customGroup = ""
    @Query(sort: [SortDescriptor(\WatchlistItem.sortOrder)])
    private var items: [WatchlistItem]

    private var existingGroups: [String] {
        var tags = Set<String>(["默认"])
        for item in items {
            tags.insert(item.groupTag)
        }
        return Array(tags).sorted()
    }

    private var effectiveGroup: String {
        groupTag == "__custom" ? customGroup.trimmingCharacters(in: .whitespacesAndNewlines) : groupTag
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("股票信息") {
                    TextField("股票代码（如 AAPL）", text: $ticker)
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                    TextField("显示名称（可选）", text: $displayName)
                }

                Section("分组") {
                    Picker("分组", selection: $groupTag) {
                        ForEach(existingGroups, id: \.self) { tag in
                            Text(tag).tag(tag)
                        }
                        Text("新建分组...").tag("__custom")
                    }
                    if groupTag == "__custom" {
                        TextField("新分组名称", text: $customGroup)
                    }
                }
            }
            .navigationTitle("添加自选股")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let item = WatchlistItem(
                            ticker: ticker,
                            displayName: displayName,
                            groupTag: effectiveGroup,
                            sortOrder: items.count
                        )
                        modelContext.insert(item)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(ticker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 320, minHeight: 280)
        #endif
    }
}
