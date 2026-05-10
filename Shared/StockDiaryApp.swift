import SwiftUI
import SwiftData

@main
struct StockDiaryApp: App {
    @State private var syncManager = IBKRSyncManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DiaryEntry.self,
            TradeEntry.self,
            TodoItem.self,
            MemoEntry.self,
            WatchlistItem.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // 改为 .automatic 以启用 iCloud 同步（需要付费开发者账号）
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(syncManager)
                .task {
                    await syncManager.autoSync(context: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
