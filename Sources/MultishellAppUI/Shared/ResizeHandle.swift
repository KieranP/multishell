import MultishellCore
import SwiftUI

/// A hairline with a wider grab area, the sidebar's edge and the Files panel's:
/// a drag resizes the column, a double-click puts its width back.
struct ResizeHandle: View {
  private static let grabWidth: Double = 8

  @Binding var width: Double
  let range: ClosedRange<Double>
  let initial: Double
  /// Where a drag that began at a width leaves it, for this edge's direction.
  let dragged: (_ start: Double, _ translation: Double, _ range: ClosedRange<Double>) -> Double
  let theme: Theme
  /// Gesture state, not `@State`: a drag the system cancels never reaches
  /// `onEnded`, and this resets either way; see `SplitDivider`.
  @GestureState private var dragStartWidth: Double?

  var body: some View {
    theme.hairline
      .frame(width: UIMetrics.hairlineThickness)
      .overlay {
        Color.clear
          .frame(width: Self.grabWidth)
          .contentShape(.rect)
          .pointerStyle(.columnResize(directions: .all))
          .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
              .updating($dragStartWidth) { _, start, _ in
                if start == nil { start = width.clamped(to: range) }
              }
              .onChanged { value in
                width = dragged(dragStartWidth ?? width, value.translation.width, range)
              }
          )
          .simultaneousGesture(TapGesture(count: 2).onEnded { width = initial })
      }
  }
}
