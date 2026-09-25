import SwiftUI

extension View {
  /// Selected is a blue outline, not a fill: a filled row tinted the state
  /// dot and hid its colour. A faint wash keeps it legible without that.
  func rowSelection(isSelected: Bool, isDropTarget: Bool = false) -> some View {
    background(
      isSelected || isDropTarget ? Color.accentColor.opacity(0.12) : .clear,
      in: RoundedRectangle(cornerRadius: 6)
    )
    // A dashed border for a hovering tab, the solid one meaning selected and
    // a row being able to be both at once.
    .overlay {
      if isDropTarget {
        RoundedRectangle(cornerRadius: 6)
          .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
      } else if isSelected {
        RoundedRectangle(cornerRadius: 6)
          .strokeBorder(Color.accentColor, lineWidth: 1.5)
      }
    }
  }
}
