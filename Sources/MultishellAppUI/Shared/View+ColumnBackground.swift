import MultishellCore
import SwiftUI

extension View {
  /// The shape a board column, a Debug Info block and a services page card share.
  func columnBackground(_ fill: Color) -> some View {
    background(fill, in: RoundedRectangle(cornerRadius: UIMetrics.columnCornerRadius))
  }
}
