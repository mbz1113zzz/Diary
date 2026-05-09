import SwiftUI

struct MacContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Label("日历", systemImage: "calendar")
                Label("交易", systemImage: "chart.line.uptrend.xyaxis")
                Label("待办", systemImage: "checkmark.circle")
            }
            .navigationTitle("StockDiary")
        } content: {
            Text("选择一个日期")
                .foregroundStyle(.secondary)
        } detail: {
            Text("选择一条记录查看详情")
                .foregroundStyle(.secondary)
        }
    }
}
