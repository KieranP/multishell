import MultishellAppCore
import MultishellCore
import SwiftUI

/// A debug table row's chevron, holding its width on a row with nothing under it.
struct DebugDisclosureChevron: View {
  let disclosure: DebugRowDisclosure
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    Image(systemName: disclosure == .expanded ? "chevron.down" : "chevron.right")
      .font(metrics.font(size: metrics.debugTableGlyphSize, weight: .semibold))
      .foregroundStyle(theme.debugInfo.textTertiary)
      .opacity(disclosure.isExpandable ? 1 : 0)
      .frame(width: UIMetrics.debugTableChevronWidth)
      // The row's own label says expanded or collapsed.
      .accessibilityHidden(true)
  }
}
