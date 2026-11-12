import CardSheetKit
import SwiftUI

@main
struct CardSheetLabApp: App {
  var body: some Scene {
    WindowGroup {
      TodayView()
    }
  }
}

struct CardItem: Identifiable, Hashable {
  let id: Int
  let title: String
  let leading: Color
  let trailing: Color
}

struct TodayView: View {
  @State private var selected: CardItem.ID?
  @State private var showsSettings = false
  @AppStorage(LabOptions.Key.snaps) private var snaps = false
  @AppStorage(LabOptions.Key.peeksNeighbours) private var peeksNeighbours = true
  @AppStorage(LabOptions.Key.dismissible) private var dismissible = true
  @AppStorage(LabOptions.Key.detents) private var detents = LabOptions.Detents.large.rawValue

  private let items: [CardItem] = [
    CardItem(id: 0, title: "Card 1", leading: .pink, trailing: .teal),
    CardItem(id: 1, title: "Card 2", leading: .indigo, trailing: .orange),
    CardItem(id: 2, title: "Card 3", leading: .green, trailing: .blue),
    CardItem(id: 3, title: "Card 4", leading: .red, trailing: .purple),
    CardItem(id: 4, title: "Card 5", leading: .brown, trailing: .cyan),
  ]

  var body: some View {
    NavigationStack {
      List(items) { item in
        Button {
          selected = item.id
        } label: {
          HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .fill(LinearGradient(colors: [item.leading, item.trailing], startPoint: .leading, endPoint: .trailing))
              .frame(width: 44, height: 44)
            Text(item.title).font(.headline).foregroundStyle(.primary)
          }
        }
        .accessibilityIdentifier("row.\(item.id)")
      }
      .navigationTitle("Today")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Lab", systemImage: "slider.horizontal.3") { showsSettings = true }
        }
      }
      .sheet(isPresented: $showsSettings) { LabSettingsView() }
      // The whole integration: SwiftUI's own presentation modifiers, plus the card's.
      .sheet(items: items, selection: $selected) { item in
        DemoCard(item: item)
          .presentationDetents(LabOptions.Detents(rawValue: detents)?.set ?? [.large])
          .presentationDragIndicator(.visible)
          .interactiveDismissDisabled(!dismissible)
          .presentationSnapping(snaps ? .always : .automatic)
          .presentationNeighbourPeek(peeksNeighbours ? 10 : 0)
      }
    }
  }
}

/// Placeholder content — the lab is about the sheet. A plain SwiftUI ScrollView: the card finds
/// it and works it.
struct DemoCard: View {
  let item: CardItem
  @AppStorage(LabOptions.Key.wrapsInNavigation) private var wrapsInNavigation = true

  var body: some View {
    if wrapsInNavigation {
      NavigationStack {
        scroll.navigationTitle(item.title)
      }
    } else {
      scroll
    }
  }

  private var scroll: some View {
    ScrollView {
      VStack(spacing: 12) {
        if !wrapsInNavigation {
          Text(item.title)
            .font(.system(size: 34, weight: .heavy))
            .foregroundStyle(.white)
            .accessibilityIdentifier("card.title.\(item.id)")
            .padding(.bottom, 16)
        }
        
        ForEach(Array([150, 110, 220, 160, 110, 260, 140, 200, 120, 240, 180, 130].enumerated()), id: \.offset) { _, height in
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.white.opacity(0.13))
            .frame(height: CGFloat(height))
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, wrapsInNavigation ? 8 : 64)
      .padding(.bottom, 24)
    }
    .scrollIndicators(.hidden)
    // A navigation bar's backdrop is the scroll edge effect; without a bar it is only a blur
    // under the status bar.
    .scrollEdgeEffectHidden(!wrapsInNavigation)
    .background(LinearGradient(colors: [item.leading, item.trailing], startPoint: .topLeading, endPoint: .trailing))
    .accessibilityIdentifier("card.\(item.id)")
  }
}
