# StockDiary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a multiplatform (Mac + iOS) stock trading diary app with SwiftUI, SwiftData, and CloudKit sync.

**Architecture:** Multiplatform SwiftUI app with ~90% shared code. Three independent SwiftData models (DiaryEntry, TradeEntry, TodoItem) associated by date. Mac uses NavigationSplitView three-column layout, iOS uses TabView. CloudKit sync via SwiftData ModelConfiguration.

**Tech Stack:** Swift, SwiftUI, SwiftData, CloudKit, Xcode multiplatform target, iOS 17+ / macOS 14+

---

### Task 1: Xcode Project Scaffold

**Files:**
- Create: `StockDiary.xcodeproj` (via Xcode project generation)
- Create: `Shared/StockDiaryApp.swift`
- Create: `Shared/ContentView.swift`
- Create: `macOS/MacContentView.swift`
- Create: `iOS/iOSContentView.swift`

This task creates the Xcode multiplatform project with the correct folder structure. Since Xcode projects are binary `.pbxproj` files, we generate the project using a Swift script that calls `xcodegen` or we create it manually. For simplicity, we'll create the Swift files and a `project.yml` for XcodeGen.

- [ ] **Step 1: Install XcodeGen if not present**

Run: `brew install xcodegen`
Expected: XcodeGen available at command line.

- [ ] **Step 2: Create project.yml**

Create `project.yml` at the project root:

```yaml
name: StockDiary
options:
  bundleIdPrefix: com.stockdiary
  deploymentTarget:
    iOS: "17.0"
    macOS: "14.0"
  xcodeVersion: "16.0"
  groupSortPosition: top
settings:
  base:
    SWIFT_VERSION: "5.9"
    DEVELOPMENT_TEAM: ""
targets:
  StockDiary:
    type: application
    platform: [iOS, macOS]
    sources:
      - path: Shared
      - path: iOS
        excludes:
          - "**/*"
        platform: [iOS]
      - path: iOS
        platform: [iOS]
      - path: macOS
        excludes:
          - "**/*"
        platform: [macOS]
      - path: macOS
        platform: [macOS]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.stockdiary.StockDiary
        INFOPLIST_KEY_CFBundleDisplayName: StockDiary
    entitlements:
      path: StockDiary.entitlements
      properties:
        com.apple.developer.icloud-container-identifiers:
          - iCloud.com.stockdiary.StockDiary
        com.apple.developer.icloud-services:
          - CloudKit
        com.apple.developer.ubiquity-kvstore-identifier: $(TeamIdentifierPrefix)com.stockdiary.StockDiary
```

- [ ] **Step 3: Create directory structure**

```bash
mkdir -p Shared/Models Shared/Views Shared/ViewModels Shared/Utils macOS iOS
```

- [ ] **Step 4: Create the app entry point**

Create `Shared/StockDiaryApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct StockDiaryApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DiaryEntry.self,
            TradeEntry.self,
            TodoItem.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
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
        }
        .modelContainer(sharedModelContainer)
    }
}
```

- [ ] **Step 5: Create ContentView with platform switch**

Create `Shared/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        #if os(macOS)
        MacContentView()
        #else
        iOSContentView()
        #endif
    }
}
```

- [ ] **Step 6: Create Mac placeholder shell**

Create `macOS/MacContentView.swift`:

```swift
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
```

- [ ] **Step 7: Create iOS placeholder shell**

Create `iOS/iOSContentView.swift`:

```swift
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
```

- [ ] **Step 8: Generate Xcode project and verify build**

```bash
xcodegen generate
xcodebuild -scheme StockDiary -destination 'platform=macOS' build
```

Expected: Build succeeds (will have warnings about missing model types — that's expected, we add them in Task 2).

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: scaffold Xcode multiplatform project with XcodeGen"
```

---

### Task 2: SwiftData Models

**Files:**
- Create: `Shared/Models/DiaryEntry.swift`
- Create: `Shared/Models/TradeEntry.swift`
- Create: `Shared/Models/TodoItem.swift`

- [ ] **Step 1: Create DiaryEntry model**

Create `Shared/Models/DiaryEntry.swift`:

```swift
import Foundation
import SwiftData

@Model
final class DiaryEntry {
    var id: UUID
    var date: Date
    var content: String
    var mood: String?
    var weather: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        content: String = "",
        mood: String? = nil,
        weather: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.content = content
        self.mood = mood
        self.weather = weather
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

- [ ] **Step 2: Create TradeEntry model**

Create `Shared/Models/TradeEntry.swift`:

```swift
import Foundation
import SwiftData

@Model
final class TradeEntry {
    var id: UUID
    var date: Date
    var ticker: String
    var direction: String
    var price: Double
    var quantity: Int
    var entryReason: String?
    var exitReason: String?
    var emotion: String?
    var pnl: Double?
    var pnlPercent: Double?
    var notes: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        ticker: String = "",
        direction: String = "买入",
        price: Double = 0.0,
        quantity: Int = 0,
        entryReason: String? = nil,
        exitReason: String? = nil,
        emotion: String? = nil,
        pnl: Double? = nil,
        pnlPercent: Double? = nil,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.ticker = ticker
        self.direction = direction
        self.price = price
        self.quantity = quantity
        self.entryReason = entryReason
        self.exitReason = exitReason
        self.emotion = emotion
        self.pnl = pnl
        self.pnlPercent = pnlPercent
        self.notes = notes
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 3: Create TodoItem model**

Create `Shared/Models/TodoItem.swift`:

```swift
import Foundation
import SwiftData

@Model
final class TodoItem {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var date: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        isCompleted: Bool = false,
        date: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.date = date
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 4: Build to verify models compile**

```bash
xcodebuild -scheme StockDiary -destination 'platform=macOS' build
```

Expected: Build succeeds with no errors.

- [ ] **Step 5: Commit**

```bash
git add Shared/Models/
git commit -m "feat: add SwiftData models (DiaryEntry, TradeEntry, TodoItem)"
```

---

### Task 3: Shared Card Views

**Files:**
- Create: `Shared/Views/DiaryCardView.swift`
- Create: `Shared/Views/TradeCardView.swift`
- Create: `Shared/Views/TodoCardView.swift`
- Create: `Shared/Utils/DateFormatters.swift`

- [ ] **Step 1: Create date formatting utilities**

Create `Shared/Utils/DateFormatters.swift`:

```swift
import Foundation

enum DateFormatters {
    static let dayDisplay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d EEEE"
        return f
    }()

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d"
        return f
    }()

    /// Returns the start of the calendar day for a given date (midnight, local time zone).
    static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// Whether two dates fall on the same calendar day.
    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }
}
```

- [ ] **Step 2: Create DiaryCardView**

Create `Shared/Views/DiaryCardView.swift`:

```swift
import SwiftUI
import SwiftData

struct DiaryCardView: View {
    let entry: DiaryEntry
    var tradeCount: Int = 0
    var todoProgress: (completed: Int, total: Int) = (0, 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let mood = entry.mood {
                    Text(mood)
                        .font(.title3)
                }
                if let weather = entry.weather {
                    Text(weather)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(DateFormatters.shortDate.string(from: entry.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !entry.content.isEmpty {
                Text(entry.content)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 12) {
                if tradeCount > 0 {
                    Label("\(tradeCount)笔交易", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if todoProgress.total > 0 {
                    Label("\(todoProgress.completed)/\(todoProgress.total)待办", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
```

- [ ] **Step 3: Create TradeCardView**

Create `Shared/Views/TradeCardView.swift`:

```swift
import SwiftUI

struct TradeCardView: View {
    let trade: TradeEntry

    private var pnlColor: Color {
        guard let pnl = trade.pnl else { return .secondary }
        if pnl > 0 { return .green }
        if pnl < 0 { return .red }
        return .secondary
    }

    private var pnlText: String {
        guard let pnl = trade.pnl else { return "" }
        let sign = pnl >= 0 ? "+" : ""
        var text = "\(sign)\(String(format: "%.2f", pnl))"
        if let pct = trade.pnlPercent {
            text += " (\(sign)\(String(format: "%.1f", pct))%)"
        }
        return text
    }

    private var accentColor: Color {
        guard let pnl = trade.pnl else { return .gray }
        if pnl > 0 { return .green }
        if pnl < 0 { return .red }
        return .gray
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(trade.ticker)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(trade.direction)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(trade.direction == "买入" ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                        .foregroundStyle(trade.direction == "买入" ? .red : .green)
                        .clipShape(Capsule())
                    Spacer()
                    Text(DateFormatters.shortDate.string(from: trade.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("$\(String(format: "%.2f", trade.price)) × \(trade.quantity)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !pnlText.isEmpty {
                    HStack {
                        Text(pnlText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(pnlColor)
                    }
                }

                HStack(spacing: 12) {
                    if let reason = trade.entryReason, !reason.isEmpty {
                        Label(reason, systemImage: "arrow.right.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let emotion = trade.emotion, !emotion.isEmpty {
                        Text(emotion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
```

- [ ] **Step 4: Create TodoCardView**

Create `Shared/Views/TodoCardView.swift`:

```swift
import SwiftUI

struct TodoCardView: View {
    let todos: [TodoItem]
    var onToggle: ((TodoItem) -> Void)? = nil

    private var completed: Int { todos.filter(\.isCompleted).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("今日待办", systemImage: "checkmark.circle")
                    .font(.headline)
                Spacer()
                Text("\(completed)/\(todos.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(todos) { todo in
                HStack(spacing: 8) {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(todo.isCompleted ? .green : .secondary)
                        .onTapGesture { onToggle?(todo) }
                    Text(todo.title)
                        .font(.body)
                        .strikethrough(todo.isCompleted)
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
```

- [ ] **Step 5: Build to verify**

```bash
xcodebuild -scheme StockDiary -destination 'platform=macOS' build
```

Expected: Build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Shared/Views/ Shared/Utils/
git commit -m "feat: add card views (diary, trade, todo) and date formatters"
```

---

### Task 4: Form / Editor Views

**Files:**
- Create: `Shared/Views/DiaryEditorView.swift`
- Create: `Shared/Views/TradeEditorView.swift`
- Create: `Shared/Views/TodoEditorView.swift`
- Create: `Shared/Views/MoodPickerView.swift`
- Create: `Shared/Views/WeatherPickerView.swift`

- [ ] **Step 1: Create MoodPickerView**

Create `Shared/Views/MoodPickerView.swift`:

```swift
import SwiftUI

struct MoodPickerView: View {
    @Binding var selected: String?

    private let moods = ["😊", "😐", "😔", "😤", "🤩", "😴", "🤔", "😰"]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(moods, id: \.self) { mood in
                Text(mood)
                    .font(.title2)
                    .padding(6)
                    .background(selected == mood ? Color.accentColor.opacity(0.2) : Color.clear)
                    .clipShape(Circle())
                    .onTapGesture {
                        selected = selected == mood ? nil : mood
                    }
            }
        }
    }
}
```

- [ ] **Step 2: Create WeatherPickerView**

Create `Shared/Views/WeatherPickerView.swift`:

```swift
import SwiftUI

struct WeatherPickerView: View {
    @Binding var selected: String?

    private let options: [(icon: String, label: String)] = [
        ("☀️", "晴"), ("⛅", "多云"), ("☁️", "阴"),
        ("🌧️", "雨"), ("❄️", "雪"), ("🌫️", "雾")
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.label) { option in
                VStack(spacing: 2) {
                    Text(option.icon)
                        .font(.title3)
                    Text(option.label)
                        .font(.caption2)
                }
                .padding(6)
                .background(selected == option.label ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    selected = selected == option.label ? nil : option.label
                }
            }
        }
    }
}
```

- [ ] **Step 3: Create DiaryEditorView**

Create `Shared/Views/DiaryEditorView.swift`:

```swift
import SwiftUI
import SwiftData

struct DiaryEditorView: View {
    @Bindable var entry: DiaryEntry
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(DateFormatters.dayDisplay.string(from: entry.date))
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("心情")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    MoodPickerView(selected: $entry.mood)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("天气")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    WeatherPickerView(selected: $entry.weather)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("今日记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $entry.content)
                        .frame(minHeight: 200)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
        .onChange(of: entry.content) { _, _ in
            entry.updatedAt = Date()
        }
        .onChange(of: entry.mood) { _, _ in
            entry.updatedAt = Date()
        }
        .onChange(of: entry.weather) { _, _ in
            entry.updatedAt = Date()
        }
    }
}
```

- [ ] **Step 4: Create TradeEditorView**

Create `Shared/Views/TradeEditorView.swift`:

```swift
import SwiftUI
import SwiftData

struct TradeEditorView: View {
    @Bindable var trade: TradeEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let directions = ["买入", "卖出"]
    private let emotions = ["冷静", "兴奋", "紧张", "犹豫", "恐惧", "贪婪"]

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("股票代码", text: $trade.ticker)
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
                Picker("方向", selection: $trade.direction) {
                    ForEach(directions, id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("价格")
                    TextField("0.00", value: $trade.price, format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                HStack {
                    Text("数量")
                    TextField("0", value: $trade.quantity, format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
            }

            Section("盈亏") {
                HStack {
                    Text("盈亏金额")
                    TextField("0.00", value: $trade.pnl, format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                HStack {
                    Text("盈亏比例 %")
                    TextField("0.0", value: $trade.pnlPercent, format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            }

            Section("复盘") {
                TextField("入场理由", text: Binding(
                    get: { trade.entryReason ?? "" },
                    set: { trade.entryReason = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...4)

                TextField("出场理由", text: Binding(
                    get: { trade.exitReason ?? "" },
                    set: { trade.exitReason = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...4)

                Picker("情绪", selection: Binding(
                    get: { trade.emotion ?? "" },
                    set: { trade.emotion = $0.isEmpty ? nil : $0 }
                )) {
                    Text("选择情绪").tag("")
                    ForEach(emotions, id: \.self) { Text($0).tag($0) }
                }

                TextField("复盘笔记", text: Binding(
                    get: { trade.notes ?? "" },
                    set: { trade.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(3...6)
            }
        }
        .formStyle(.grouped)
    }
}
```

- [ ] **Step 5: Create TodoEditorView**

Create `Shared/Views/TodoEditorView.swift`:

```swift
import SwiftUI
import SwiftData

struct TodoEditorView: View {
    let date: Date
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [TodoItem]
    @State private var newTodoTitle = ""

    init(date: Date) {
        self.date = date
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        _todos = Query(
            filter: #Predicate<TodoItem> { todo in
                todo.date >= start && todo.date < end
            },
            sort: [SortDescriptor(\.createdAt)]
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(todos) { todo in
                HStack(spacing: 8) {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(todo.isCompleted ? .green : .secondary)
                        .onTapGesture {
                            todo.isCompleted.toggle()
                        }
                    Text(todo.title)
                        .strikethrough(todo.isCompleted)
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    Spacer()
                    Button(role: .destructive) {
                        modelContext.delete(todo)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("添加待办...", text: $newTodoTitle)
                    .onSubmit { addTodo() }
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                Button(action: addTodo) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.accentColor)
                }
                .disabled(newTodoTitle.isEmpty)
                .buttonStyle(.plain)
            }
        }
    }

    private func addTodo() {
        guard !newTodoTitle.isEmpty else { return }
        let todo = TodoItem(
            title: newTodoTitle,
            date: DateFormatters.startOfDay(date)
        )
        modelContext.insert(todo)
        newTodoTitle = ""
    }
}
```

- [ ] **Step 6: Build to verify**

```bash
xcodebuild -scheme StockDiary -destination 'platform=macOS' build
```

Expected: Build succeeds.

- [ ] **Step 7: Commit**

```bash
git add Shared/Views/
git commit -m "feat: add editor views (diary, trade, todo, mood/weather pickers)"
```

---

### Task 5: ViewModel Layer

**Files:**
- Create: `Shared/ViewModels/DiaryViewModel.swift`

- [ ] **Step 1: Create DiaryViewModel**

Create `Shared/ViewModels/DiaryViewModel.swift`:

```swift
import Foundation
import SwiftData
import SwiftUI

@Observable
final class DiaryViewModel {
    var selectedDate: Date = Date()

    /// Returns the start of day for the selected date.
    var selectedDayStart: Date {
        DateFormatters.startOfDay(selectedDate)
    }

    /// Returns the end of the selected day (start of next day).
    var selectedDayEnd: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: selectedDayStart)!
    }

    /// Finds or creates a DiaryEntry for the given date.
    func findOrCreateDiaryEntry(for date: Date, in context: ModelContext) -> DiaryEntry {
        let dayStart = DateFormatters.startOfDay(date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!

        let predicate = #Predicate<DiaryEntry> { entry in
            entry.date >= dayStart && entry.date < dayEnd
        }
        let descriptor = FetchDescriptor<DiaryEntry>(predicate: predicate)

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let newEntry = DiaryEntry(date: dayStart)
        context.insert(newEntry)
        return newEntry
    }

    /// Creates a new TradeEntry for the given date.
    func createTradeEntry(for date: Date, in context: ModelContext) -> TradeEntry {
        let trade = TradeEntry(date: DateFormatters.startOfDay(date))
        context.insert(trade)
        return trade
    }

    /// Returns the count of trades for a given date.
    func tradeCount(for date: Date, in context: ModelContext) -> Int {
        let dayStart = DateFormatters.startOfDay(date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        let predicate = #Predicate<TradeEntry> { trade in
            trade.date >= dayStart && trade.date < dayEnd
        }
        let descriptor = FetchDescriptor<TradeEntry>(predicate: predicate)
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Returns (completed, total) todo counts for a given date.
    func todoProgress(for date: Date, in context: ModelContext) -> (completed: Int, total: Int) {
        let dayStart = DateFormatters.startOfDay(date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        let predicate = #Predicate<TodoItem> { todo in
            todo.date >= dayStart && todo.date < dayEnd
        }
        let descriptor = FetchDescriptor<TodoItem>(predicate: predicate)
        guard let todos = try? context.fetch(descriptor) else { return (0, 0) }
        return (todos.filter(\.isCompleted).count, todos.count)
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -scheme StockDiary -destination 'platform=macOS' build
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Shared/ViewModels/
git commit -m "feat: add DiaryViewModel with date-based queries"
```

---

### Task 6: Day Detail View (Shared)

**Files:**
- Create: `Shared/Views/DayDetailView.swift`

This is the main detail view that assembles diary, trades, and todos for a single day.

- [ ] **Step 1: Create DayDetailView**

Create `Shared/Views/DayDetailView.swift`:

```swift
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
                // Diary section
                if let entry = diaryEntry {
                    DiaryEditorView(entry: entry)
                }

                // Trades section
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
                        }
                    }
                }
                .padding(.horizontal)

                // Todo section
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
        .sheet(isPresented: $showingTradeEditor) {
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
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        let predicate = #Predicate<DiaryEntry> { entry in
            entry.date >= dayStart && entry.date < dayEnd
        }
        let descriptor = FetchDescriptor<DiaryEntry>(predicate: predicate)
        if let existing = try? modelContext.fetch(descriptor).first {
            diaryEntry = existing
        } else {
            let newEntry = DiaryEntry(date: dayStart)
            modelContext.insert(newEntry)
            diaryEntry = newEntry
        }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -scheme StockDiary -destination 'platform=macOS' build
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Shared/Views/DayDetailView.swift
git commit -m "feat: add DayDetailView assembling diary, trades, and todos"
```

---

### Task 7: Mac Navigation Shell

**Files:**
- Modify: `macOS/MacContentView.swift`

- [ ] **Step 1: Implement full Mac three-column layout**

Replace the content of `macOS/MacContentView.swift`:

```swift
import SwiftUI
import SwiftData

enum MacSidebarItem: String, Hashable, CaseIterable {
    case calendar = "日历"
    case trades = "交易"
    case todos = "待办"

    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .trades: return "chart.line.uptrend.xyaxis"
        case .todos: return "checkmark.circle"
        }
    }
}

struct MacContentView: View {
    @State private var selectedSidebar: MacSidebarItem? = .calendar
    @State private var selectedDate: Date = Date()
    @Query(sort: [SortDescriptor(\DiaryEntry.date, order: .reverse)])
    private var allDiaryEntries: [DiaryEntry]

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebar) {
                ForEach(MacSidebarItem.allCases, id: \.self) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                }
            }
            .navigationTitle("StockDiary")
        } content: {
            switch selectedSidebar {
            case .calendar, .none:
                CalendarListView(selectedDate: $selectedDate)
            case .trades:
                TradeListView(selectedDate: $selectedDate)
            case .todos:
                TodoListView(selectedDate: $selectedDate)
            }
        } detail: {
            DayDetailView(date: selectedDate)
                .id(Calendar.current.startOfDay(for: selectedDate))
        }
    }
}

// MARK: - Calendar List

struct CalendarListView: View {
    @Binding var selectedDate: Date
    @Query(sort: [SortDescriptor(\DiaryEntry.date, order: .reverse)])
    private var entries: [DiaryEntry]

    var body: some View {
        List(selection: Binding(
            get: { Calendar.current.startOfDay(for: selectedDate) },
            set: { if let d = $0 { selectedDate = d } }
        )) {
            DatePicker("跳转日期", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(.bottom, 8)

            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if let mood = entry.mood { Text(mood) }
                        Text(DateFormatters.dayDisplay.string(from: entry.date))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    if !entry.content.isEmpty {
                        Text(entry.content)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(Calendar.current.startOfDay(for: entry.date))
            }
        }
        .navigationTitle("日历")
    }
}

// MARK: - Trade List

struct TradeListView: View {
    @Binding var selectedDate: Date
    @Query(sort: [SortDescriptor(\TradeEntry.date, order: .reverse)])
    private var trades: [TradeEntry]

    var body: some View {
        List {
            ForEach(trades) { trade in
                TradeCardView(trade: trade)
                    .onTapGesture {
                        selectedDate = trade.date
                    }
            }
        }
        .navigationTitle("交易")
    }
}

// MARK: - Todo List

struct TodoListView: View {
    @Binding var selectedDate: Date
    @Query(sort: [SortDescriptor(\TodoItem.date, order: .reverse)])
    private var todos: [TodoItem]

    var body: some View {
        List {
            ForEach(todos) { todo in
                HStack {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(todo.isCompleted ? .green : .secondary)
                        .onTapGesture { todo.isCompleted.toggle() }
                    VStack(alignment: .leading) {
                        Text(todo.title)
                            .strikethrough(todo.isCompleted)
                        Text(DateFormatters.shortDate.string(from: todo.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onTapGesture { selectedDate = todo.date }
            }
        }
        .navigationTitle("待办")
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -scheme StockDiary -destination 'platform=macOS' build
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add macOS/
git commit -m "feat: implement Mac three-column NavigationSplitView layout"
```

---

### Task 8: iOS Navigation Shell

**Files:**
- Modify: `iOS/iOSContentView.swift`

- [ ] **Step 1: Implement full iOS TabView layout**

Replace the content of `iOS/iOSContentView.swift`:

```swift
import SwiftUI
import SwiftData

struct iOSContentView: View {
    @State private var showingNewEntrySheet = false
    @State private var newEntryType: NewEntryType?

    enum NewEntryType: Identifiable {
        case diary, trade
        var id: Self { self }
    }

    var body: some View {
        TabView {
            DiaryTabView()
                .tabItem {
                    Label("日记", systemImage: "book")
                }

            TradeTabView()
                .tabItem {
                    Label("交易", systemImage: "chart.line.uptrend.xyaxis")
                }

            Text("")
                .tabItem {
                    Label("新建", systemImage: "plus.circle.fill")
                }

            TodoTabView()
                .tabItem {
                    Label("待办", systemImage: "checkmark.circle")
                }

            SettingsTabView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .onAppear {
            // Intercept the "new" tab: we use an overlay button approach instead
        }
        .overlay(alignment: .bottom) {
            NewEntryButton { type in
                newEntryType = type
            }
            .offset(y: -28)
        }
        .sheet(item: $newEntryType) { type in
            NavigationStack {
                switch type {
                case .diary:
                    NewDiarySheetView()
                case .trade:
                    NewTradeSheetView()
                }
            }
        }
    }
}

// MARK: - New Entry Button

struct NewEntryButton: View {
    var onTap: (iOSContentView.NewEntryType) -> Void
    @State private var showingMenu = false

    var body: some View {
        Menu {
            Button {
                onTap(.diary)
            } label: {
                Label("新建日记", systemImage: "book")
            }
            Button {
                onTap(.trade)
            } label: {
                Label("新建交易", systemImage: "chart.line.uptrend.xyaxis")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white, .accentColor)
                .shadow(radius: 4)
        }
    }
}

// MARK: - Diary Tab

struct DiaryTabView: View {
    @Query(sort: [SortDescriptor(\DiaryEntry.date, order: .reverse)])
    private var entries: [DiaryEntry]

    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    NavigationLink {
                        DayDetailView(date: entry.date)
                    } label: {
                        DiaryCardView(entry: entry)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
            .listStyle(.plain)
            .navigationTitle("日记")
        }
    }
}

// MARK: - Trade Tab

struct TradeTabView: View {
    @Query(sort: [SortDescriptor(\TradeEntry.date, order: .reverse)])
    private var trades: [TradeEntry]

    var body: some View {
        NavigationStack {
            List {
                ForEach(trades) { trade in
                    NavigationLink {
                        TradeEditorView(trade: trade)
                            .navigationTitle(trade.ticker)
                    } label: {
                        TradeCardView(trade: trade)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
            .listStyle(.plain)
            .navigationTitle("交易")
        }
    }
}

// MARK: - Todo Tab

struct TodoTabView: View {
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("日期", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(.horizontal)
                TodoEditorView(date: selectedDate)
                    .padding()
                Spacer()
            }
            .navigationTitle("待办")
        }
    }
}

// MARK: - Settings Tab

struct SettingsTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("数据") {
                    HStack {
                        Text("iCloud 同步")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}

// MARK: - New Entry Sheets

struct NewDiarySheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var entry: DiaryEntry?

    var body: some View {
        Group {
            if let entry {
                DiaryEditorView(entry: entry)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("新建日记")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    if let entry { modelContext.delete(entry) }
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { dismiss() }
            }
        }
        .onAppear {
            let newEntry = DiaryEntry(date: Calendar.current.startOfDay(for: Date()))
            modelContext.insert(newEntry)
            entry = newEntry
        }
    }
}

struct NewTradeSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var trade: TradeEntry?

    var body: some View {
        Group {
            if let trade {
                TradeEditorView(trade: trade)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("新建交易")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    if let trade { modelContext.delete(trade) }
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { dismiss() }
            }
        }
        .onAppear {
            let newTrade = TradeEntry(date: Calendar.current.startOfDay(for: Date()))
            modelContext.insert(newTrade)
            trade = newTrade
        }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -scheme StockDiary -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add iOS/
git commit -m "feat: implement iOS TabView navigation with new entry sheets"
```

---

### Task 9: Cross-Platform Color Compatibility

**Files:**
- Create: `Shared/Utils/PlatformCompat.swift`

macOS and iOS use different names for system colors (`NSColor` vs `UIColor`, `.systemBackground` etc.). This task adds compatibility.

- [ ] **Step 1: Create platform compatibility helpers**

Create `Shared/Utils/PlatformCompat.swift`:

```swift
import SwiftUI

#if os(macOS)
import AppKit

extension Color {
    static let systemBackground = Color(NSColor.windowBackgroundColor)
    static let secondarySystemBackground = Color(NSColor.controlBackgroundColor)
}
#endif
```

- [ ] **Step 2: Build both platforms**

```bash
xcodebuild -scheme StockDiary -destination 'platform=macOS' build
xcodebuild -scheme StockDiary -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: Both builds succeed.

- [ ] **Step 3: Commit**

```bash
git add Shared/Utils/PlatformCompat.swift
git commit -m "feat: add macOS/iOS color compatibility helpers"
```

---

### Task 10: Final Integration & Cleanup

**Files:**
- Modify: `Shared/ContentView.swift` (no changes needed — already has platform switch)
- Verify: full build and run on both platforms

- [ ] **Step 1: Build macOS**

```bash
xcodebuild -scheme StockDiary -destination 'platform=macOS' build
```

Expected: Build succeeds with no errors.

- [ ] **Step 2: Build iOS**

```bash
xcodebuild -scheme StockDiary -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: Build succeeds with no errors.

- [ ] **Step 3: Final commit and push**

```bash
git add -A
git status
# If there are any uncommitted changes:
git commit -m "chore: final integration cleanup"
git push origin main
```

Expected: All code pushed to remote.
