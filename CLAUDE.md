# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About

Maccy is a lightweight macOS clipboard manager built with Swift/SwiftUI. It monitors the system pasteboard, stores clipboard history in a local SwiftData database, and presents it via a floating panel triggered by a global hotkey. Bundle ID: `org.p0deje.Maccy`. Requires macOS 14+.

## Build & Run

This is an Xcode project (no workspace/CocoaPods). Open `Maccy.xcodeproj` and use the `Maccy` scheme.

```sh
# Build
xcodebuild -project Maccy.xcodeproj -scheme Maccy -configuration Debug build

# Run tests (unit + UI)
xcodebuild -project Maccy.xcodeproj -scheme Maccy -testPlan Maccy test

# Run a single test class
xcodebuild -project Maccy.xcodeproj -scheme Maccy -testPlan Maccy \
  -only-testing:MaccyTests/SearchTests test

# Run a single test method
xcodebuild -project Maccy.xcodeproj -scheme Maccy -testPlan Maccy \
  -only-testing:MaccyTests/SearchTests/testFuzzySearch test

# Lint
swiftlint
```

Tests pass `enable-testing` via the test plan's command-line arguments. This switches Storage to in-memory mode and disables Sparkle auto-updates. Note: `HistoryTests` are skipped in the test plan due to SwiftData issues in tests.

## Architecture

### Entry Point & App Lifecycle
- `MaccyApp.swift` — `@main` SwiftUI App. Uses a hidden `MenuBarExtra` (no dock icon).
- `AppDelegate.swift` — Sets up the status bar item, clipboard monitoring, and the floating panel. Bridges to `AppState.shared`.

### Core Data Flow
1. **Clipboard** (`Clipboard.swift`) — Singleton. Polls `NSPasteboard.general` on a timer (default 500ms). Fires `onNewCopy` hooks when new content is detected. Handles filtering (ignored types, apps, regexps) and pasting via CGEvent.
2. **History** (`Observables/History.swift`) — Singleton `@Observable`. Manages the in-memory list of `HistoryItemDecorator` items. Receives new items from Clipboard, handles deduplication, pinning, sorting, search, and size limits.
3. **Storage** (`Storage.swift`) — Singleton. SwiftData `ModelContainer` backed by SQLite at `~/Library/Application Support/Maccy/Storage.sqlite`.

### Data Models (SwiftData)
- `HistoryItem` (`Models/HistoryItem.swift`) — `@Model`. Stores metadata (title, application, pin, timestamps, copy count). Has cascade relationship to `HistoryItemContent`.
- `HistoryItemContent` (`Models/HistoryItemContent.swift`) — `@Model`. Stores pasteboard type (as string) and raw data bytes.

### UI Layer
- `FloatingPanel.swift` — Custom `NSPanel` subclass with floating panel traits (non-activating, stays above other windows).
- `ContentView.swift` — Root SwiftUI view. Contains header (search), history list, footer, and slideout preview.
- `Views/` — SwiftUI views: `HistoryListView`, `HistoryItemView`, `FooterView`, `HeaderView`, `SearchFieldView`, `SlideoutView`, `SlideoutContentView`, `KeyHandlingView`, etc.

### State Management
All state objects are `@Observable` (Swift Observation framework):
- `AppState` — Central hub. Holds references to `History`, `Footer`, `Popup`, `NavigationManager`, `SlideoutController`.
- `Popup` — Controls panel open/close, handles cycle vs toggle mode for the global hotkey.
- `NavigationManager` — Keyboard navigation, selection tracking.
- `HistoryItemDecorator` — View model wrapping `HistoryItem`. Manages display title, image thumbnails, pin shortcuts, search highlighting.
- `SlideoutController` — Manages the preview slideout panel.

### Key Dependencies (Swift Package Manager)
- **Defaults** — Type-safe UserDefaults. All preference keys defined in `Extensions/Defaults.Keys+Names.swift`.
- **KeyboardShortcuts** — Global hotkey registration.
- **Sauce** — Keyboard key code mapping.
- **Fuse** — Fuzzy search (used in `Search.swift`).
- **Sparkle** — Auto-updates.
- **Settings** — Preferences window framework (multi-pane).
- **LaunchAtLogin-Modern** — Launch at login support.
- **swift-log** — Logging.

### Settings Panes
Located in `Settings/`: General, Storage, Appearance, Pins, Ignore (with sub-views for apps, pasteboard types, regexps), Advanced.

### Localization
Extensive i18n support (30+ languages). Translations managed via Weblate. BartyCrouch (`.bartycrouch.toml`) used for syncing string catalogs.

## Linting
SwiftLint is configured (`.swiftlint.yml`). Disabled rules: `multiple_closures_with_trailing_closure`, `non_optional_string_data_conversion`, `todo`. Line length ignores comments.

Periphery (`.periphery.yml`) configured for dead code detection on the `Maccy` target.

## Conventions
- Singletons used extensively: `Clipboard.shared`, `History.shared`, `Storage.shared`, `AppState.shared`.
- User preferences use `Defaults[.keyName]` (not raw `UserDefaults`).
- Pasteboard type extensions in `Extensions/NSPasteboard.PasteboardType+Types.swift`.
- Search supports four modes: exact, fuzzy, regex, mixed (cascading fallback).
