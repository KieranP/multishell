import MultishellCore
import SwiftUI

extension View {
  /// The shape a board column and a Debug Info block share.
  func columnBackground(_ fill: Color) -> some View {
    background(fill, in: RoundedRectangle(cornerRadius: UIMetrics.columnCornerRadius))
  }
}
