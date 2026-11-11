import MultishellCore
import SwiftUI

/// The rounded well a list's filter sits in, the sidebar's and the Files
/// panel's alike, inset as its list is so it lines up with the rows' selection.
struct FilterWellModifier: ViewModifier {
  let palette: AreaPalette
  let metrics: UIMetrics
  let listSideInset: Double

  func body(content: Content) -> some View {
    content
      .padding(.horizontal, UIMetrics.sidebarRowSideInset)
      .frame(height: metrics.filterWellHeight)
      .background(palette.fill, in: RoundedRectangle(cornerRadius: UIMetrics.rowCornerRadius))
      .padding(.horizontal, listSideInset)
  }
}
