import XCTest
import Defaults
@testable import Maccy

@MainActor
class ClipboardSetTests: XCTestCase {
  let savedSize = Defaults[.size]
  let savedSortBy = Defaults[.sortBy]
  let savedActiveSet = Defaults[.activeClipboardSet]
  let history = History.shared

  override func setUp() {
    super.setUp()
    history.clearAll()
    clearAllSets()
    Defaults[.size] = 10
    Defaults[.sortBy] = .firstCopiedAt
    history.activeSetName = nil
  }

  override func tearDown() {
    super.tearDown()
    history.activeSetName = nil
    clearAllSets()
    Defaults[.size] = savedSize
    Defaults[.sortBy] = savedSortBy
    Defaults[.activeClipboardSet] = savedActiveSet
  }

  // MARK: - Set CRUD

  func testCreateSet() {
    history.createSet(name: "Work")
    XCTAssertEqual(history.availableSets.count, 1)
    XCTAssertEqual(history.availableSets.first?.name, "Work")
  }

  func testCreateMultipleSets() {
    history.createSet(name: "Work")
    history.createSet(name: "Personal")
    XCTAssertEqual(history.availableSets.count, 2)
    XCTAssertEqual(history.availableSets.map(\.name), ["Work", "Personal"])
  }

  func testCreateDuplicateSetIsIgnored() {
    history.createSet(name: "Work")
    history.createSet(name: "Work")
    XCTAssertEqual(history.availableSets.count, 1)
  }

  func testDeleteSet() {
    history.createSet(name: "Work")
    let clipboardSet = history.availableSets.first!
    history.deleteSet(clipboardSet)
    XCTAssertEqual(history.availableSets.count, 0)
  }

  func testDeleteActiveSetResetsToAll() {
    history.createSet(name: "Work")
    history.activeSetName = "Work"
    let clipboardSet = history.availableSets.first!
    history.deleteSet(clipboardSet)
    XCTAssertNil(history.activeSetName)
  }

  func testDeleteSetUnassignsItems() {
    history.createSet(name: "Work")
    history.activeSetName = "Work"
    history.add(historyItem("foo"))
    let clipboardSet = history.availableSets.first!
    history.deleteSet(clipboardSet)
    // Item should still exist in "All" view
    XCTAssertEqual(history.all.count, 1)
    XCTAssertNil(history.all.first?.item.clipboardSet)
  }

  func testRenameSet() {
    history.createSet(name: "Work")
    let clipboardSet = history.availableSets.first!
    history.renameSet(clipboardSet, to: "Office")
    XCTAssertEqual(history.availableSets.first?.name, "Office")
  }

  func testRenameActiveSetUpdatesActiveSetName() {
    history.createSet(name: "Work")
    history.activeSetName = "Work"
    let clipboardSet = history.availableSets.first!
    history.renameSet(clipboardSet, to: "Office")
    XCTAssertEqual(history.activeSetName, "Office")
  }

  // MARK: - Active Set & Filtering

  func testDefaultActiveSetIsNil() {
    XCTAssertNil(history.activeSetName)
  }

  func testAllItemsVisibleWhenNoActiveSet() {
    history.add(historyItem("foo"))
    history.add(historyItem("bar"))
    XCTAssertEqual(history.items.count, 2)
  }

  func testFilteringByActiveSet() {
    history.createSet(name: "Work")

    history.activeSetName = "Work"
    history.add(historyItem("work item"))

    history.activeSetName = nil
    history.add(historyItem("general item"))

    // "All" shows both
    XCTAssertEqual(history.items.count, 2)

    // "Work" shows only work item
    history.activeSetName = "Work"
    XCTAssertEqual(history.items.count, 1)
    XCTAssertEqual(history.items.first?.item.title, "work item")
  }

  func testNewItemAssignedToActiveSet() {
    history.createSet(name: "Work")
    history.activeSetName = "Work"
    let decorator = history.add(historyItem("foo"))
    XCTAssertEqual(decorator.item.clipboardSet?.name, "Work")
  }

  func testNewItemHasNoSetWhenAllActive() {
    history.createSet(name: "Work")
    history.activeSetName = nil
    let decorator = history.add(historyItem("foo"))
    XCTAssertNil(decorator.item.clipboardSet)
  }

  func testItemsInSet() {
    history.createSet(name: "Work")
    history.activeSetName = "Work"
    history.add(historyItem("item 1"))
    history.add(historyItem("item 2"))

    let workSet = history.availableSets.first(where: { $0.name == "Work" })!
    XCTAssertEqual(workSet.items.count, 2)

    let titles = workSet.items.sorted(by: { $0.lastCopiedAt > $1.lastCopiedAt }).map(\.title)
    XCTAssertEqual(titles, ["item 2", "item 1"])
  }

  func testActiveSetPersistedToDefaults() {
    history.createSet(name: "Work")
    history.activeSetName = "Work"
    XCTAssertEqual(Defaults[.activeClipboardSet], "Work")
    history.activeSetName = nil
    XCTAssertNil(Defaults[.activeClipboardSet])
  }

  // MARK: - Set Switching

  func testSwitchToNextSet() {
    history.createSet(name: "Work")
    history.createSet(name: "Personal")

    // Start at "All" (nil)
    XCTAssertNil(history.activeSetName)

    history.switchToNextSet()
    XCTAssertEqual(history.activeSetName, "Work")

    history.switchToNextSet()
    XCTAssertEqual(history.activeSetName, "Personal")

    // Wraps around to "All"
    history.switchToNextSet()
    XCTAssertNil(history.activeSetName)
  }

  func testSwitchToPreviousSet() {
    history.createSet(name: "Work")
    history.createSet(name: "Personal")

    // Start at "All" (nil), go backward wraps to last
    history.switchToPreviousSet()
    XCTAssertEqual(history.activeSetName, "Personal")

    history.switchToPreviousSet()
    XCTAssertEqual(history.activeSetName, "Work")

    history.switchToPreviousSet()
    XCTAssertNil(history.activeSetName)
  }

  func testSwitchSetWithNoSetsDoesNothing() {
    history.switchToNextSet()
    XCTAssertNil(history.activeSetName)

    history.switchToPreviousSet()
    XCTAssertNil(history.activeSetName)
  }

  // MARK: - Clear Behavior

  func testClearWithActiveSetUnassignsItems() {
    history.createSet(name: "Work")
    history.activeSetName = "Work"
    history.add(historyItem("foo"))
    history.add(historyItem("bar"))
    XCTAssertEqual(history.items.count, 2)

    history.clear()

    // Items removed from "Work" view
    XCTAssertEqual(history.items.count, 0)

    // Items still exist in "All"
    history.activeSetName = nil
    XCTAssertEqual(history.items.count, 2)
  }

  func testClearWithActiveSetPreservesPinnedItems() {
    history.createSet(name: "Work")
    history.activeSetName = "Work"
    let pinned = history.add(historyItem("pinned"))
    pinned.togglePin()
    history.add(historyItem("unpinned"))

    history.clear()

    // Pinned item still in the set
    XCTAssertEqual(history.items.count, 1)
    XCTAssertEqual(history.items.first?.item.title, "pinned")
  }

  func testClearWithAllActiveDeletesItems() {
    history.add(historyItem("foo"))
    history.add(historyItem("bar"))
    XCTAssertNil(history.activeSetName)

    history.clear()

    XCTAssertEqual(history.items.count, 0)
    XCTAssertEqual(history.all.count, 0)
  }

  // MARK: - Helpers

  private func historyItem(_ value: String) -> HistoryItem {
    let contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: value.data(using: .utf8)
      )
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.numberOfCopies = 1
    item.title = item.generateTitle()

    return item
  }

  private func clearAllSets() {
    for clipboardSet in history.availableSets {
      history.deleteSet(clipboardSet)
    }
    history.loadSets()
  }
}
