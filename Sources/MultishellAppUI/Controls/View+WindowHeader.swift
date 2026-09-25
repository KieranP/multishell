import SwiftUI

extension View {
  /// The strip across the top of the window, which the title bar's double
  /// click reaches through; one definition so the three cannot drift.
  func windowHeader(fill: Color = .clear) -> some View {
    padding(.horizontal, 14)
      .frame(height: UIMetrics.headerHeight)
      .background(fill)
      .titleBarDoubleClick()
  }
}
