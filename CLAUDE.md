# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

StockDiary — 个人美股交易复盘日记 app，Mac + iOS 双端，iCloud 同步。

## Tech Stack

- SwiftUI + SwiftData + CloudKit
- Minimum: iOS 17.0+ / macOS 14.0+ (Sonoma)
- Xcode project with multiplatform target

## Architecture

Multiplatform SwiftUI app with ~90% shared code:

- `Shared/Models/` — SwiftData `@Model` classes (DiaryEntry, TradeEntry, TodoItem)
- `Shared/Views/` — Reusable SwiftUI views (cards, forms, editors)
- `Shared/ViewModels/` — Business logic, data queries
- `macOS/` — Mac-specific shell: `NavigationSplitView` three-column layout
- `iOS/` — iOS-specific shell: `TabView` navigation

Data models are independent, associated by date (not relationships).

## Build & Run

```bash
# Build for macOS
xcodebuild -scheme StockDiary -destination 'platform=macOS' build

# Build for iOS simulator
xcodebuild -scheme StockDiary -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild -scheme StockDiary -destination 'platform=macOS' test
```

## CloudKit Sync

SwiftData `ModelConfiguration` with CloudKit enabled. Requires:
- Apple Developer account
- CloudKit capability + Background Modes (remote notifications) in Xcode
- iCloud container: `iCloud.com.yourname.StockDiary`

## Conventions

- Use Chinese for user-facing strings
- SwiftData `@Model` classes go in `Shared/Models/`
- Platform-specific code only in `macOS/` or `iOS/` directories
- Price/PnL fields use `Double` (SwiftData does not natively support `Decimal`)

## Design Spec

See `docs/superpowers/specs/2026-05-09-stock-diary-design.md` for full design document.
