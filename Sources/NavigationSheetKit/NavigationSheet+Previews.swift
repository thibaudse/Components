#if os(iOS)
import SwiftUI

// The sheet's job is to be the right height for whatever screen is showing, and the ways that
// can go wrong are all about *how* a screen states its height: fixed content, a scroll view,
// a scroll view with a bottom bar, content shorter than the bar, content taller than the
// screen. Each preview destination below is one of those cases.

private enum PreviewScreen: Hashable, Sendable {
  case fixed
  case fixedWithoutBar
  case scrolling
  case scrollingWithoutBar
  case scrollingWithBottomBar
  case scrollingWithBottomBarWithoutBar
  case tiny
  case tallerThanTheSheet
}

// MARK: - Root

private struct PreviewRoot: View {
  private let screens: [(PreviewScreen, String)] = [
    (.fixed, "Fixed"),
    (.fixedWithoutBar, "Fixed, no bar"),
    (.scrolling, "Scrolling"),
    (.scrollingWithoutBar, "Scrolling, no bar"),
    (.scrollingWithBottomBar, "Scrolling + bottom bar"),
    (.scrollingWithBottomBarWithoutBar, "Bottom bar, no top bar"),
    (.tiny, "Shorter than the bar"),
    (.tallerThanTheSheet, "Taller than the sheet")
  ]

  var body: some View {
    VStack(spacing: 12) {
      ForEach(screens, id: \.0) { screen, title in
        NavigationSheetLink(screen) {
          Text(verbatim: title)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(.horizontal, 20)
  }
}

// MARK: - Shared Content

/// Three 100pt blocks and two 16pt gaps: 332pt, so a wrong detent is obvious rather than
/// plausible.
private struct PreviewBlocks: View {
  var body: some View {
    VStack(spacing: 16) {
      ForEach([Color.red, .green, .blue], id: \.self) { color in
        color.opacity(0.4)
          .frame(height: 100)
          .overlay {
            Text(verbatim: "100pt")
              .font(.body.bold())
          }
      }
    }
    .padding(.horizontal, 20)
  }
}

private struct PreviewBottomBar: View {
  var body: some View {
    Color.yellow.opacity(0.6)
      .frame(height: 44)
      .overlay {
        Text(verbatim: "Bar 44pt")
          .font(.body.bold())
      }
  }
}

// MARK: - Destinations

private struct PreviewDestination: View {
  let screen: PreviewScreen

  var body: some View {
    switch screen {
      case .fixed:
        PreviewBlocks()
          .navigationSheetTitle("Fixed")

      case .fixedWithoutBar:
        PreviewBlocks()
          .navigationSheetToolbar(.hidden)

      case .scrolling:
        ScrollView { PreviewBlocks() }
          .scrollBounceBehavior(.basedOnSize)
          .navigationSheetTitle("Scrolling")

      case .scrollingWithoutBar:
        ScrollView { PreviewBlocks() }
          .scrollBounceBehavior(.basedOnSize)
          .navigationSheetToolbar(.hidden)

      case .scrollingWithBottomBar:
        ScrollView { PreviewBlocks() }
          .scrollBounceBehavior(.basedOnSize)
          .safeAreaInset(edge: .bottom, spacing: 0) { PreviewBottomBar() }
          .navigationSheetTitle("Bottom bar")

      case .scrollingWithBottomBarWithoutBar:
        ScrollView { PreviewBlocks() }
          .scrollBounceBehavior(.basedOnSize)
          .safeAreaInset(edge: .bottom, spacing: 0) { PreviewBottomBar() }
          .navigationSheetToolbar(.hidden)

      case .tiny:
        Text(verbatim: "Hello world")
          .navigationSheetTitle("Tiny")

      case .tallerThanTheSheet:
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<100, id: \.self) { index in
              Text(verbatim: "Item \(index.formatted(.number))")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
            }
          }
          .padding(.horizontal, 20)
        }
        .navigationSheetTitle("Capped at large")
    }
  }
}

// MARK: - Previews

#Preview("Defaults") {
  @Previewable @State var isPresented = true
  @Previewable @State var path = NavigationSheetPath()

  PreviewStage(isPresented: $isPresented)
    .navigationSheet(isPresented: $isPresented, path: $path) {
      PreviewRoot()
        .navigationSheetTitle("Navigation sheet")
        .navigationSheetDestination(for: PreviewScreen.self) { screen in
          PreviewDestination(screen: screen)
        }
    }
}

/// The same sheet with every replaceable piece replaced — a dark background, a custom bar
/// background, a different indicator, a "Done" button in place of the close button, and
/// toolbar buttons the caller styles.
#Preview("Chrome replaced") {
  @Previewable @State var isPresented = true
  @Previewable @State var path = NavigationSheetPath()

  PreviewStage(isPresented: $isPresented)
    .navigationSheet(isPresented: $isPresented, path: $path) {
      PreviewRoot()
        .navigationSheetTitle("Replaced")
        .navigationSheetNavigationButton {
          PreviewDoneButton()
        }
        .navigationSheetDestination(for: PreviewScreen.self) { screen in
          PreviewDestination(screen: screen)
        }
    }
    .navigationSheetBackground {
      Color.black.opacity(0.95)
    }
    .navigationSheetBarBackground {
      LinearGradient(colors: [.indigo.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
    }
    .navigationSheetDragIndicator {
      Capsule()
        .fill(.orange)
        .frame(width: 40, height: 4)
    }
    .preferredColorScheme(.dark)
}

#Preview("Item binding") {
  @Previewable @State var item: PreviewItem? = PreviewItem(title: "Hello world")

  Color.teal
    .ignoresSafeArea()
    .overlay {
      if item == nil {
        Button("Present") { item = PreviewItem(title: "Hello world") }
          .buttonStyle(.borderedProminent)
      }
    }
    .navigationSheet(item: $item) { value in
      Text(verbatim: value.title)
        .font(.title2.weight(.semibold))
        .navigationSheetToolbar(.hidden)
    }
}

// MARK: - Preview Support

private struct PreviewItem: Identifiable {
  let id = UUID()
  let title: String
}

private struct PreviewStage: View {
  @Binding var isPresented: Bool

  var body: some View {
    Color.teal
      .ignoresSafeArea()
      .overlay {
        if !isPresented {
          Button("Present") { isPresented = true }
            .buttonStyle(.borderedProminent)
        }
      }
  }
}

private struct PreviewDoneButton: View {
  @Environment(\.navigationSheetDismiss) private var dismiss

  var body: some View {
    Button("Done") { dismiss() }
      .buttonStyle(.bordered)
  }
}
#endif
