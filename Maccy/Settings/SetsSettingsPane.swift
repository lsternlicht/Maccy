import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import Logging

struct SetsSettingsPane: View {
  @Environment(AppState.self) private var appState
  @Environment(\.modelContext) private var modelContext

  @Query(sort: \ClipboardSet.order)
  private var sets: [ClipboardSet]

  @State private var viewedSetID: PersistentIdentifier?
  private let logger = Logger(label: "org.p0deje.Maccy.SetsSettingsPane")

  var body: some View {
    Group {
      if let viewedSetID = viewedSetID, let viewedSet = sets.first(where: { $0.id == viewedSetID }) {
        SetItemsView(clipboardSet: viewedSet, viewedSetID: $viewedSetID)
          .onAppear {
            logger.info("Viewing set '\(viewedSet.name)' with \(viewedSet.items.count) items")
          }
      } else {
        MainSetsView(sets: sets, viewedSetID: $viewedSetID)
      }
    }
    .frame(minWidth: 500, minHeight: 300)
    .padding()
  }
}

private struct MainSetsView: View {
  var sets: [ClipboardSet]
  @Binding var viewedSetID: PersistentIdentifier?
  @Environment(AppState.self) private var appState
  private let logger = Logger(label: "org.p0deje.Maccy.MainSetsView")

  @State private var selection: PersistentIdentifier?
  @State private var newSetName = ""
  @State private var isRenaming = false
  @State private var renameValue = ""

  var body: some View {
    VStack(alignment: .leading) {
      Table(sets, selection: $selection) {
        TableColumn("Name", value: \.name)
        TableColumn("Items") { clipboardSet in
          Text("\(clipboardSet.items.count)")
        }
        .width(60)
        TableColumn("Created") { clipboardSet in
          Text(clipboardSet.createdAt, style: .date)
        }
        .width(100)
      }
      .onDeleteCommand {
        deleteSelected()
      }
      .contextMenu {
        if let selection, let clipboardSet = sets.first(where: { $0.id == selection }) {
          Button("Open") {
            viewedSetID = clipboardSet.id
          }
          Button("Rename...") {
            renameValue = clipboardSet.name
            isRenaming = true
          }
          Divider()
          Button("Delete", role: .destructive) {
            deleteSelected()
          }
        }
      }
      .simultaneousGesture(TapGesture(count: 2).onEnded {
        if let selection {
          viewedSetID = selection
        }
      })

      HStack {
        TextField("New set name", text: $newSetName)
          .frame(width: 150)
          .onSubmit {
            addSet()
          }

        Button("Add") {
          addSet()
        }
        .disabled(newSetName.trimmingCharacters(in: .whitespaces).isEmpty)

        Button("Rename") {
          if let selection, let clipboardSet = sets.first(where: { $0.id == selection }) {
            renameValue = clipboardSet.name
            isRenaming = true
          }
        }
        .disabled(selection == nil)

        Button("Delete") {
          deleteSelected()
        }
        .disabled(selection == nil)

        Spacer()

        Button("Export Selected") {
          exportSelected()
        }
        .disabled(selection == nil)

        Button("Export All") {
          exportAllSets()
        }
        .disabled(sets.isEmpty)
      }
      .sheet(isPresented: $isRenaming) {
        VStack(spacing: 16) {
          Text("Rename Set")
            .font(.headline)
          TextField("New name", text: $renameValue)
            .textFieldStyle(.roundedBorder)
            .frame(width: 200)
            .onSubmit {
              performRename()
            }
          HStack {
            Button("Cancel") { isRenaming = false }
            Button("OK") { performRename() }
              .keyboardShortcut(.defaultAction)
              .disabled(renameValue.trimmingCharacters(in: .whitespaces).isEmpty)
          }
        }
        .padding()
      }

      Text("Clipboard sets let you organize clipboard items into named collections. New copies are routed to the active set.")
        .foregroundStyle(.gray)
        .controlSize(.small)
    }
  }

  private func addSet() {
    logger.info("Adding new set '\(newSetName)'")
    appState.history.createSet(name: newSetName)
    newSetName = ""
  }

  private func performRename() {
    guard let selection,
          let clipboardSet = sets.first(where: { $0.id == selection }) else {
      return
    }
    let trimmed = renameValue.trimmingCharacters(in: .whitespaces)
    if !trimmed.isEmpty && trimmed != clipboardSet.name {
      logger.info("Renaming set '\(clipboardSet.name)' to '\(trimmed)'")
      appState.history.renameSet(clipboardSet, to: trimmed)
    }
    isRenaming = false
  }

  private func deleteSelected() {
    guard let selection,
          let clipboardSet = sets.first(where: { $0.id == selection }) else {
      return
    }
    logger.info("Deleting set '\(clipboardSet.name)'")
    appState.history.deleteSet(clipboardSet)
    self.selection = nil
  }

  private func exportSelected() {
    guard let selection,
          let clipboardSet = sets.first(where: { $0.id == selection }) else {
      return
    }
    exportSets([clipboardSet], defaultName: clipboardSet.name)
  }

  private func exportAllSets() {
    exportSets(sets, defaultName: "All Sets")
  }

  private func exportSets(_ setsToExport: [ClipboardSet], defaultName: String) {
    let exported = setsToExport.map { clipboardSet in
      ClipboardSetExport(
        name: clipboardSet.name,
        createdAt: clipboardSet.createdAt,
        items: clipboardSet.items.map { item in
          ClipboardSetExport.Item(
            title: item.title,
            text: item.text,
            firstCopiedAt: item.firstCopiedAt,
            lastCopiedAt: item.lastCopiedAt,
            numberOfCopies: item.numberOfCopies,
            application: item.application
          )
        }
      )
    }

    guard let data = try? JSONEncoder.exportEncoder.encode(exported) else { return }

    let panel = NSSavePanel()
    panel.nameFieldStringValue = "\(defaultName).json"
    panel.allowedContentTypes = [.json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    try? data.write(to: url)
  }
}

private struct SetItemsView: View {
  let clipboardSet: ClipboardSet
  @Binding var viewedSetID: PersistentIdentifier?
  @Environment(AppState.self) private var appState
  @State private var selection: Set<PersistentIdentifier> = []
  private let logger = Logger(label: "org.p0deje.Maccy.SetItemsView")

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Button {
          viewedSetID = nil
        } label: {
          Image(systemName: "chevron.left")
        }
        .buttonStyle(.borderless)

        Text(clipboardSet.name)
          .font(.headline)

        Spacer()
      }
      .padding(.bottom, 8)

      Table(clipboardSet.items.sorted(by: { $0.lastCopiedAt > $1.lastCopiedAt }), selection: $selection) {
        TableColumn("Title", value: \.title)
        TableColumn("Copied") { item in
          Text(item.lastCopiedAt, style: .date)
        }
        .width(100)
      }

      HStack {
        Button("Copy Selected") {
          copySelected()
        }
        .disabled(selection.isEmpty)

        Button("Copy All") {
          copyAll()
        }
        .disabled(clipboardSet.items.isEmpty)

        Spacer()
      }
    }
  }

  private func copySelected() {
    let selectedItems = clipboardSet.items.filter { selection.contains($0.id) }
    logger.info("Copying \(selectedItems.count) selected items from set '\(clipboardSet.name)'")
    copyItems(selectedItems)
  }

  private func copyAll() {
    logger.info("Copying all \(clipboardSet.items.count) items from set '\(clipboardSet.name)'")
    copyItems(clipboardSet.items)
  }

  @MainActor
  private func copyItems(_ items: [HistoryItem]) {
    let text = items
      .sorted(by: { $0.lastCopiedAt > $1.lastCopiedAt })
      .map { $0.previewableText }
      .joined(separator: "\n")
    Clipboard.shared.copy(text)
  }
}

private struct ClipboardSetExport: Encodable {
  struct Item: Encodable {
    var title: String
    var text: String?
    var firstCopiedAt: Date
    var lastCopiedAt: Date
    var numberOfCopies: Int
    var application: String?
  }

  var name: String
  var createdAt: Date
  var items: [Item]
}

private extension JSONEncoder {
  static let exportEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()
}

#Preview {
  SetsSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
    .modelContainer(Storage.shared.container)
}
