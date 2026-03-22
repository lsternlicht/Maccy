import Foundation
import SwiftData

@Model
class ClipboardSet {
  var name: String = ""
  var createdAt: Date = Date.now
  var order: Int = 0

  @Relationship(inverse: \HistoryItem.clipboardSet)
  var items: [HistoryItem] = []

  init(name: String, order: Int = 0) {
    self.name = name
    self.order = order
  }
}
