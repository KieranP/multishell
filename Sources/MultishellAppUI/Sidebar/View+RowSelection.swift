import MultishellCore
import SwiftUI

extension View {
  /// Selected is an outline, not a fill: a filled row tinted the state dot
  /// and hid its colour. A faint wash keeps it legible without that.
  func rowSelection(_ theme: Theme, isSelected: Bool, isDropTarget: Bool = false) -> some View {
    let outline = theme.color(.selection, in: .projectsPanel)
    return background(
      isSelected || isDropTarget ? theme.color(.selectionBackground, in: .projectsPanel) : .clear,
      in: RoundedRectangle(cornerRadius: UIMetrics.rowCornerRadius),
    )
    // A dashed border for a hovering tab, the solid one meaning selected and
    // a row being able to be both at once.
    .overlay {
      if isDropTarget {
        RoundedRectangle(cornerRadius: UIMetrics.rowCornerRadius)
          .strokeBorder(outline, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
      } else if isSelected {
        RoundedRectangle(cornerRadius: UIMetrics.rowCornerRadius)
          .strokeBorder(outline, lineWidth: 1.5)
      }
    }
  }
}
