import SwiftData
import SwiftUI

struct SetsSettingsPane: View {
  @Environment(AppState.self) private var appState
  @Environment(\.modelContext) private var modelContext

  @Query(sort: \ClipboardSet.order)
  private var sets: [ClipboardSet]

  @State private var selection: PersistentIdentifier?
  @State private var newSetName = ""

  var body: some View {
    VStack(alignment: .leading) {
      Table(sets, selection: $selection) {
        TableColumn("Name") { clipboardSet in
          SetNameField(clipboardSet: clipboardSet, appState: appState)
        }

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

      HStack {
        TextField("New set name", text: $newSetName)
          .frame(width: 200)
          .onSubmit {
            addSet()
          }

        Button("Add") {
          addSet()
        }
        .disabled(newSetName.trimmingCharacters(in: .whitespaces).isEmpty)

        Button("Delete") {
          deleteSelected()
        }
        .disabled(selection == nil)
      }

      Text("Clipboard sets let you organize clipboard items into named collections. New copies are routed to the active set.")
        .foregroundStyle(.gray)
        .controlSize(.small)
    }
    .frame(minWidth: 500, minHeight: 300)
    .padding()
  }

  private func addSet() {
    appState.history.createSet(name: newSetName)
    newSetName = ""
  }

  private func deleteSelected() {
    guard let selection,
          let clipboardSet = sets.first(where: { $0.id == selection }) else {
      return
    }
    appState.history.deleteSet(clipboardSet)
    self.selection = nil
  }
}

private struct SetNameField: View {
  @Bindable var clipboardSet: ClipboardSet
  var appState: AppState
  @State private var editableName: String = ""

  var body: some View {
    TextField("", text: $editableName)
      .onAppear { editableName = clipboardSet.name }
      .onSubmit {
        let trimmed = editableName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != clipboardSet.name else { return }
        appState.history.renameSet(clipboardSet, to: trimmed)
      }
  }
}

#Preview {
  SetsSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
    .modelContainer(Storage.shared.container)
}
