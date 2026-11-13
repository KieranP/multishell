import MultishellAppCore
import MultishellCore
import SwiftUI

/// A page on the panel's header: a glyph, underlined while chosen, named in a
/// tooltip while the pointer rests on it.
struct FilesPanelModeTab<Glyph: View>: View {
  private static var underlineHeight: Double { 2 }
  private static var underlineInset: Double { 7 }
  private static var dotSide: Double { 5 }

  let model: AppModel
  let mode: FilesPanelMode
  let name: String
  let theme: Theme
  /// What waits on the page, such as Review's comments to send: drawn as a dot
  /// and said to VoiceOver, which sees no dot.
  var waiting: String?
  @ViewBuilder let glyph: () -> Glyph

  @State private var isHovered = false

  private var isSelected: Bool { model.shownFilesPanelMode == mode }

  var body: some View {
    Button {
      model.setFilesPanelMode(mode)
    } label: {
      glyph()
        .frame(width: UIMetrics.headerGlyphButtonSide, height: UIMetrics.headerGlyphButtonSide)
        .glyphHover(
          isHovered,
          palette: theme.header,
          resting: isSelected ? theme.header.text : theme.header.textTertiary,
        )
        .overlay(alignment: .topTrailing) {
          if waiting != nil {
            Circle()
              .fill(theme.color(for: .attention, on: theme.header))
              .frame(width: Self.dotSide, height: Self.dotSide)
              .padding(5)
          }
        }
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .tracksHover($isHovered)
    .accessibilityLabel(name)
    .accessibilityValue(waiting ?? "")
    .frame(maxHeight: .infinity)
    .overlay(alignment: .bottom) {
      if isSelected {
        Capsule()
          .fill(theme.header.textSecondary)
          .frame(height: Self.underlineHeight)
          .padding(.horizontal, Self.underlineInset)
      }
    }
    .hoverTooltip(name, palette: theme.header, metrics: model.metrics)
    .selectableButtonTraits(isSelected: isSelected)
  }
}
