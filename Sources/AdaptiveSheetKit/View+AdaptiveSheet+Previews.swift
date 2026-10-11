#if os(iOS)
import SwiftUI

// Each preview is one of the cases `adaptiveSheet` promises, with SwiftUI's own presentation modifiers
// inside the content to show they still apply.

#Preview("Static") {
  Color.clear
    .adaptiveSheet(isPresented: .constant(true)) {
      VStack(spacing: 12) {
        Text(verbatim: "A sheet as tall as its content")
          .font(.headline)
        Text(verbatim: "No detents to pick: the sheet measures what it shows and takes that height.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Button {} label: {
          Text(verbatim: "Got it")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.top, 20)
      }
      .multilineTextAlignment(.center)
      .padding(.horizontal, 20)
      .padding(.vertical, 32)
      .presentationDragIndicator(.visible)
      .presentationBackground(.thinMaterial)
    }
}

#Preview("ScrollView") {
  Color.clear
    .adaptiveSheet(isPresented: .constant(true)) {
      ScrollView {
        VStack(spacing: 8) {
          ForEach(1...4, id: \.self) { index in
            Text(verbatim: "Row \(index)")
              .frame(maxWidth: .infinity, minHeight: .previewRowHeight, alignment: .leading)
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 32)
      }
      .scrollBounceBehavior(.basedOnSize)
      .presentationDragIndicator(.visible)
    }
}

// Taller than the screen: the sheet stops at the large detent and the scroll view takes the rest.
#Preview("Overflow") {
  Color.clear
    .adaptiveSheet(isPresented: .constant(true)) {
      ScrollView {
        LazyVStack(spacing: 8) {
          ForEach(1...60, id: \.self) { index in
            Text(verbatim: "Row \(index)")
              .frame(maxWidth: .infinity, minHeight: .previewRowHeight, alignment: .leading)
          }
        }
        .padding(.horizontal, 16)
      }
      .presentationDragIndicator(.visible)
    }
}

// A navigation stack inside the sheet. Each row pushes a screen with a different number of rows, so a
// push and a pop should each resize the sheet to the screen now on top — measured in UIKit, off that
// screen's scroll view, with the navigation bar as its top inset.
#Preview("NavigationStack") {
  @Previewable @State var path: [Int] = []

  Color.clear
    .adaptiveSheet(isPresented: .constant(true)) {
      NavigationStack(path: $path) {
        PreviewNavigationScreen(rowCount: 3, onSelect: { path.append($0) })
          .navigationTitle(Text(verbatim: "Title"))
          .navigationDestination(for: Int.self) { rowCount in
            PreviewNavigationScreen(rowCount: rowCount, onSelect: { path.append($0) })
              .navigationTitle(Text(verbatim: "\(rowCount) rows"))
          }
      }
      .presentationDragIndicator(.visible)
    }
}

// The same stack with screens that do not scroll — the root included. Nothing reports a static screen's
// height, so each is re-read while it is on top: the sheet should fit the root, each pushed screen, and a
// screen that grows when its Add row button is tapped.
#Preview("NavigationStack, static screens") {
  @Previewable @State var path: [Int] = []

  Color.clear
    .adaptiveSheet(isPresented: .constant(true)) {
      NavigationStack(path: $path) {
        PreviewNavigationScreen(rowCount: 2, scrolls: false, onSelect: { path.append($0) })
          .navigationTitle(Text(verbatim: "Title"))
          .navigationDestination(for: Int.self) { rowCount in
            PreviewNavigationScreen(rowCount: rowCount, scrolls: false, onSelect: { path.append($0) })
              .navigationTitle(Text(verbatim: "\(rowCount) rows"))
          }
      }
      .presentationDragIndicator(.visible)
    }
}

/// One screen of the NavigationStack previews: rows that each push a screen of that many rows, and a
/// button that adds a row to this one.
private struct PreviewNavigationScreen: View {
  let rowCount: Int
  var scrolls = true
  let onSelect: (Int) -> Void

  @State private var addedRows = 0

  var body: some View {
    Group {
      if scrolls {
        ScrollView { rows }
          .scrollBounceBehavior(.basedOnSize)
      } else {
        rows
      }
    }
    .navigationBarTitleDisplayMode(.inline)
  }

  private var rows: some View {
    VStack(spacing: 8) {
      ForEach(1...rowCount + addedRows, id: \.self) { index in
        Button {
          onSelect(index + 1)
        } label: {
          Text(verbatim: "Push \(index + 1) rows")
            .frame(maxWidth: .infinity, minHeight: .previewRowHeight, alignment: .leading)
        }
        .buttonStyle(.bordered)
      }

      Button {
        addedRows += 1
      } label: {
        Text(verbatim: "Add row")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 16)
  }
}

// The content changing while the sheet is up: the sheet resizes with it, animated.
#Preview("Resizing") {
  @Previewable @State var rowCount = 1

  Color.clear
    .adaptiveSheet(isPresented: .constant(true)) {
      VStack(spacing: 8) {
        ForEach(1...rowCount, id: \.self) { index in
          Text(verbatim: "Row \(index)")
            .frame(maxWidth: .infinity, minHeight: .previewRowHeight, alignment: .leading)
        }

        HStack(spacing: 8) {
          Button { rowCount -= 1 } label: { Text(verbatim: "Remove") }
            .buttonStyle(.bordered)
            .disabled(rowCount == 1)
          Button { rowCount += 1 } label: { Text(verbatim: "Add") }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 12)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 32)
      .presentationDragIndicator(.visible)
      .interactiveDismissDisabled()
    }
}

private extension CGFloat {
  /// A row tall enough that the previews measure realistic content.
  static let previewRowHeight: CGFloat = 48
}
#endif
