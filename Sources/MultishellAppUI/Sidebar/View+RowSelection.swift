import MultishellCore
import SwiftUI

extension View {
  /// Selected is a wash with no outline: the pane in front draws its focus ring
  /// in the same colour, and two rings said where the keyboard was twice.
  func rowSelection(_ theme: Theme, isSelected: Bool, isDropTarget: Bool = false) -> some View {
    background(
      isSelected || isDropTarget ? theme.color(.selectionBackground, in: .projectsPanel) : .clear,
      in: RoundedRectangle(cornerRadius: UIMetrics.rowCornerRadius),
    )
    .overlay {
      if isDropTarget {
        RoundedRectangle(cornerRadius: UIMetrics.rowCornerRadius)
          .strokeBorder(
            theme.color(.selection, in: .projectsPanel),
            style: StrokeStyle(lineWidth: 2, dash: [4, 3]),
          )
      }
    }
  }
}
