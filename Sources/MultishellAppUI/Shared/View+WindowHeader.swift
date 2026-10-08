import SwiftUI

extension View {
  /// The strip across the top of the window, which the title bar's double
  /// click reaches through; one definition so the headers cannot drift.
  func windowHeader(fill: Color = .clear) -> some View {
    padding(.horizontal, UIMetrics.panelSideInset)
      .frame(height: UIMetrics.headerHeight)
      .background(fill)
      .titleBarDoubleClick()
  }
}
