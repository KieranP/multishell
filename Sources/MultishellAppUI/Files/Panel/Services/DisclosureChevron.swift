import SwiftUI

/// The chevron a section or an earlier run turns as it opens; the button it
/// sits in says the state to VoiceOver, so the glyph says nothing.
struct DisclosureChevron: View {
  let isExpanded: Bool
  let metrics: UIMetrics

  var body: some View {
    Image(systemName: "chevron.right")
      .font(metrics.font(size: metrics.servicePageMarkSize, weight: .semibold))
      .rotationEffect(.degrees(isExpanded ? 90 : 0))
      .accessibilityHidden(true)
  }
}
