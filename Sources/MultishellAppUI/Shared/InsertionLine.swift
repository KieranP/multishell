import SwiftUI

/// Where a dragged tab or project will land: an accent line on the edge of the
/// view the pointer is over, drawn half past it.
struct InsertionLine: View {
  /// The line's own direction: upright between tabs, lying down between
  /// project blocks.
  let axis: Axis
  /// On the trailing or bottom edge rather than the leading or top one.
  let isAfter: Bool

  var body: some View {
    let shift: CGFloat = isAfter ? 1 : -1
    switch axis {
    case .vertical:
      Capsule()
        .fill(Color.accentColor)
        .frame(width: 2)
        .padding(.vertical, 6)
        .offset(x: shift)
    case .horizontal:
      Capsule()
        .fill(Color.accentColor)
        .frame(height: 2)
        .padding(.horizontal, 4)
        .offset(y: shift)
    }
  }
}
