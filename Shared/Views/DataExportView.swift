import SwiftUI
import SwiftData

struct DataExportView: View {
    @Query(sort: [SortDescriptor(\TradeEntry.date, order: .reverse)])
    private var trades: [TradeEntry]
    @State private var selectedFormat: TradeExportFormat = .csv
    @State private var exportDocument = TextExportDocument(text: "")
    @State private var exportFilename = "StockDiary-Trades.csv"
    @State private var isExporting = false

    var body: some View {
        List {
            Section("交易备份") {
                Picker("格式", selection: $selectedFormat) {
                    ForEach(TradeExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    prepareExport()
                } label: {
                    Label("导出交易记录", systemImage: "square.and.arrow.up")
                }
                .disabled(trades.isEmpty)

                HStack {
                    Text("记录数")
                    Spacer()
                    Text("\(trades.count)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("内容") {
                Text("导出文件包含日期、股票代码、方向、价格、数量、盈亏、复盘文字和策略标签。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("数据导出")
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: selectedFormat.contentType,
            defaultFilename: exportFilename
        ) { _ in }
    }

    private func prepareExport() {
        exportDocument = TradeExportBuilder.document(for: selectedFormat, trades: trades)
        exportFilename = TradeExportBuilder.filename(for: selectedFormat)
        isExporting = true
    }
}
