import SwiftUI

/// The Lab screen's switches, each one a modifier on the card's content.
enum LabOptions {
  enum Key {
    static let snaps = "snaps"
    static let peeksNeighbours = "peeksNeighbours"
    static let dismissible = "dismissible"
    static let detents = "detents"
    static let wrapsInNavigation = "wrapsInNavigation"
  }

  enum Detents: String, CaseIterable, Identifiable {
    case large, medium, mediumAndLarge
    var id: String { rawValue }

    var title: String {
      switch self {
      case .large: ".large"
      case .medium: ".medium"
      case .mediumAndLarge: ".medium + .large"
      }
    }

    var set: Set<PresentationDetent> {
      switch self {
      case .large: [.large]
      case .medium: [.medium]
      case .mediumAndLarge: [.medium, .large]
      }
    }
  }
}

struct LabSettingsView: View {
  @AppStorage(LabOptions.Key.snaps) private var snaps = false
  @AppStorage(LabOptions.Key.peeksNeighbours) private var peeksNeighbours = true
  @AppStorage(LabOptions.Key.dismissible) private var dismissible = true
  @AppStorage(LabOptions.Key.detents) private var detents = LabOptions.Detents.large.rawValue
  @AppStorage(LabOptions.Key.wrapsInNavigation) private var wrapsInNavigation = true
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Detents", selection: $detents) {
            ForEach(LabOptions.Detents.allCases) { Text($0.title).tag($0.rawValue) }
          }
          Toggle("Dismissible (not interactiveDismissDisabled)", isOn: $dismissible)
        } header: {
          Text("SwiftUI's own modifiers")
        }
        Section("Content") {
          Toggle("In a NavigationStack", isOn: $wrapsInNavigation)
        }
        Section("Card sheet modifiers") {
          Toggle("Always snap (presentationSnapping)", isOn: $snaps)
          Toggle("Neighbours peek (presentationNeighbourPeek)", isOn: $peeksNeighbours)
        }
      }
      .navigationTitle("Lab")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}
