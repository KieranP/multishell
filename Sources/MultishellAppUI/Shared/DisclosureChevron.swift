import SwiftUI

/// The chevron a project, a folder, a section or an earlier run turns as it
/// opens; the row it sits in says the state to VoiceOver, so the glyph says nothing.
struct DisclosureChevron: View {
  let isExpanded: Bool
  let size: Double
  let weight: Font.Weight
  let metrics: UIMetrics

  var body: some View {
    Image(systemName: "chevron.right")
      .font(metrics.font(size: size, weight: weight))
      .rotationEffect(.degrees(isExpanded ? 90 : 0))
      .accessibilityHidden(true)
  }
}
