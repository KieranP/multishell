import MultishellCore
import SwiftUI

/// One segment's face, the selected one on its section's pill: shared by a
/// `SegmentedSwitch` and a toggle drawn as a single segment.
struct SegmentFace<Content: View>: View {
  private static var height: Double { 18 }

  let isSelected: Bool
  let palette: AreaPalette
  let metrics: UIMetrics
  /// Shares the well's width with its siblings rather than hugging its title.
  var fillsWidth = false
  @ViewBuilder let content: () -> Content

  var body: some View {
    content()
      .font(metrics.font(size: metrics.caption, weight: isSelected ? .semibold : .regular))
      .foregroundStyle(isSelected ? palette.text : palette.textSecondary)
      .padding(.horizontal, 8)
      .frame(maxWidth: fillsWidth ? .infinity : nil)
      .frame(height: Self.height)
      .background(
        isSelected ? palette.color(.selectionBackground) : .clear,
        in: RoundedRectangle(cornerRadius: 4),
      )
      .contentShape(.rect)
  }
}
