#if os(iOS)
import SwiftUI

private struct PreviewGame: Identifiable {
  let id: Int
  var title: String { "Game \(id + 1)" }
}

@available(iOS 26.0, *)
private struct PreviewCards: View {
  @State private var selection: PreviewGame.ID?
  let detents: Set<PresentationDetent>
  private let games = (0..<4).map(PreviewGame.init)

  var body: some View {
    List(games) { game in
      Button(game.title) { selection = game.id }
    }
    .sheet(items: games, selection: $selection) { game in
      NavigationStack {
        ScrollView {
          VStack(spacing: 12) {
            ForEach(0..<12, id: \.self) { _ in
              RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.quaternary)
                .frame(height: 140)
            }
          }
          .padding()
        }
        .navigationTitle(game.title)
      }
      .presentationDetents(detents)
      .presentationDragIndicator(.visible)
    }
  }
}

@available(iOS 26.0, *)
#Preview("Cards, .large") {
  PreviewCards(detents: [.large])
}

@available(iOS 26.0, *)
#Preview("Cards, .medium and .large") {
  PreviewCards(detents: [.medium, .large])
}

@available(iOS 26.0, *)
#Preview("One card") {
  @Previewable @State var isPresented = true
  Button("Show") { isPresented = true }
    .sheet(isPresented: $isPresented, style: .card) {
      Text("A card")
        .presentationDetents([.medium, .large])
    }
}
#endif
