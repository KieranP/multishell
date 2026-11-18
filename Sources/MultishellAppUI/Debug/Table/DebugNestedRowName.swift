import MultishellCore
import SwiftUI

/// A nested row's name, indented under its parent's title by its level, an
/// arrow before it below the first level.
struct DebugNestedRowName: View {
  let name: String
  let isMonospaced: Bool
  let indentLevel: Int
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 4) {
      if indentLevel > 0 {
        Image(systemName: "arrow.turn.down.right")
          .font(metrics.font(size: metrics.debugTableGlyphSize))
          .foregroundStyle(theme.debugInfo.textTertiary)
          .accessibilityHidden(true)
      }
      Text(name)
        .font(
          isMonospaced
            ? .system(size: metrics.caption, design: .monospaced)
            : metrics.font(size: metrics.caption)
        )
    }
    .padding(
      .leading,
      UIMetrics.debugNestedRowIndent + Double(indentLevel) * UIMetrics.debugNestedRowIndent,
    )
  }
}
