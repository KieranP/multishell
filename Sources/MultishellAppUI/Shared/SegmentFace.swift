import MultishellCore
import SwiftUI

/// One segment's face, the selected one on its section's pill: shared by a
/// `SegmentedSwitch` and a toggle drawn as a single segment.
struct SegmentFace<Content: View>: View {
  private static var height: Double { 18 }

  let isSelected: Bool
  let theme: Theme
  let section: InterfaceSection
  let metrics: UIMetrics
  @ViewBuilder let content: () -> Content

  var body: some View {
    let palette = AreaPalette(theme, section)
    content()
      .font(metrics.font(size: metrics.caption, weight: isSelected ? .semibold : .regular))
      .foregroundStyle(isSelected ? palette.text : palette.textSecondary)
      .padding(.horizontal, 8)
      .frame(height: Self.height)
      .background(
        isSelected ? theme.color(.selectionBackground, in: section) : .clear,
        in: RoundedRectangle(cornerRadius: 4),
      )
      .contentShape(.rect)
  }
}
