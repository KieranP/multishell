import MultishellCore
import SwiftUI

/// What the workspace holds, under a hairline at the foot of the tree.
struct SidebarFooter: View {
  let countsText: String
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    HStack {
      Text(countsText)
        .font(.system(size: metrics.caption))
        .foregroundStyle(theme.textTertiary)
      Spacer()
    }
    .padding(.horizontal, UIMetrics.panelSideInset)
    .frame(height: 30)
    .hairline(.top, theme)
  }
}
