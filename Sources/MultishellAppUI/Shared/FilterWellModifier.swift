import MultishellCore
import SwiftUI

/// The rounded well a list's filter sits in, the sidebar's and the Files
/// panel's alike.
struct FilterWellModifier: ViewModifier {
  let theme: Theme
  let metrics: UIMetrics

  func body(content: Content) -> some View {
    content
      .padding(.horizontal, UIMetrics.sidebarRowSideInset)
      .frame(height: metrics.sidebarFilterHeight)
      .background(theme.faintFill, in: RoundedRectangle(cornerRadius: UIMetrics.rowCornerRadius))
      .padding(.horizontal, UIMetrics.sidebarListSideInset)
  }
}
