import SwiftUI

/// The branching arrow a worker count is drawn with, on the chip and atop
/// the list under it.
struct SubagentGlyph: View {
  let metrics: UIMetrics

  var body: some View {
    Image(systemName: "arrow.triangle.branch")
      .font(.system(size: metrics.badge - 1, weight: .semibold))
  }
}
