import SwiftUI

struct SetSwitcherView: View {
  @Environment(AppState.self) private var appState

  @State private var isAddingSet = false
  @State private var newSetName = ""

  private var activeLabel: String {
    appState.history.activeSetName ?? "All"
  }

  var body: some View {
    HStack(spacing: 4) {
      Menu {
        Button {
          appState.history.activeSetName = nil
        } label: {
          HStack {
            Text("All")
            if appState.history.activeSetName == nil {
              Image(systemName: "checkmark")
            }
          }
        }

        if !appState.history.availableSets.isEmpty {
          Divider()
        }

        ForEach(appState.history.availableSets, id: \.persistentModelID) { clipboardSet in
          Button {
            appState.history.activeSetName = clipboardSet.name
          } label: {
            HStack {
              Text(clipboardSet.name)
              if appState.history.activeSetName == clipboardSet.name {
                Image(systemName: "checkmark")
              }
            }
          }
        }
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "tray.2")
            .font(.system(size: 10))
          Text(activeLabel)
            .lineLimit(1)
            .font(.system(size: 12))
          Image(systemName: "chevron.down")
            .font(.system(size: 8))
        }
        .foregroundStyle(.secondary)
      }
      .menuStyle(.borderlessButton)
      .fixedSize()

      Spacer()

      if isAddingSet {
        HStack(spacing: 4) {
          TextField("Set name", text: $newSetName)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .frame(width: 100)
            .onSubmit {
              commitNewSet()
            }

          Button {
            commitNewSet()
          } label: {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 12))
          }
          .buttonStyle(.plain)
          .disabled(newSetName.trimmingCharacters(in: .whitespaces).isEmpty)

          Button {
            isAddingSet = false
            newSetName = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 12))
          }
          .buttonStyle(.plain)
        }
      } else {
        Button {
          isAddingSet = true
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, Popup.horizontalPadding + 5)
    .padding(.vertical, 4)
    .readHeight(appState, into: \.popup.setSwitcherHeight)
  }

  private func commitNewSet() {
    appState.history.createSet(name: newSetName)
    newSetName = ""
    isAddingSet = false
  }
}
