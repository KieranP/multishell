import MultishellCore
import SwiftUI

extension View {
  /// The fill a board column and a debug panel block share.
  func columnBackground(_ theme: Theme) -> some View {
    background(theme.columnColor, in: RoundedRectangle(cornerRadius: UIMetrics.columnCornerRadius))
  }
}
