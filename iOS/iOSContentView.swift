import SwiftUI

struct iOSContentView: View {
    var body: some View {
        TabView {
            Text("日记")
                .tabItem {
                    Label("日记", systemImage: "book")
                }
            Text("交易")
                .tabItem {
                    Label("交易", systemImage: "chart.line.uptrend.xyaxis")
                }
            Text("新建")
                .tabItem {
                    Label("新建", systemImage: "plus.circle.fill")
                }
            Text("待办")
                .tabItem {
                    Label("待办", systemImage: "checkmark.circle")
                }
            Text("设置")
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
    }
}
