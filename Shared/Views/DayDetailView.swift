import SwiftUI
import SwiftData

struct DayDetailView: View {
    let date: Date
    @Environment(\.modelContext) private var modelContext
    @State private var diaryEntry: DiaryEntry?
    @Query private var trades: [TradeEntry]
    @State private var showingTradeEditor = false
    @State private var selectedTrade: TradeEntry?

    init(date: Date) {
        self.date = date
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        _trades = Query(
            filter: #Predicate<TradeEntry> { trade in
                trade.date >= start && trade.date < end
            },
            sort: [SortDescriptor(\.createdAt)]
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let entry = diaryEntry {
                    DiaryEditorView(entry: entry)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("交易记录")
                            .font(.headline)
                        Spacer()
                        Button {
                            let trade = TradeEntry(date: Calendar.current.startOfDay(for: date))
                            modelContext.insert(trade)
                            selectedTrade = trade
                            showingTradeEditor = true
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                    }

                    if trades.isEmpty {
                        Text("今天没有交易记录")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(trades) { trade in
                            TradeCardView(trade: trade)
                                .onTapGesture {
                                    selectedTrade = trade
                                    showingTradeEditor = true
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        modelContext.delete(trade)
                                    } label: {
                                        Label("删除交易", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("待办事项")
                        .font(.headline)
                        .padding(.horizontal)
                    TodoEditorView(date: date)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            loadOrCreateDiary()
        }
        .onDisappear {
            cleanupEmptyDiary()
        }
        .sheet(isPresented: $showingTradeEditor, onDismiss: cleanupEmptySelectedTrade) {
            if let trade = selectedTrade {
                NavigationStack {
                    TradeEditorView(trade: trade)
                        .navigationTitle(trade.ticker.isEmpty ? "新建交易" : trade.ticker)
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") { showingTradeEditor = false }
                            }
                        }
                }
                #if os(macOS)
                .frame(minWidth: 400, minHeight: 500)
                #endif
            }
        }
    }

    private func loadOrCreateDiary() {
        diaryEntry = DiaryViewModel.findOrCreateDiaryEntry(for: date, in: modelContext)
    }

    private func cleanupEmptyDiary() {
        diaryEntry = DiaryViewModel.cleanupEmptyDiaryIfNeeded(diaryEntry, in: modelContext)
    }

    private func cleanupEmptySelectedTrade() {
        guard let selectedTrade, selectedTrade.isEmpty else {
            selectedTrade = nil
            return
        }
        modelContext.delete(selectedTrade)
        self.selectedTrade = nil
    }
}
