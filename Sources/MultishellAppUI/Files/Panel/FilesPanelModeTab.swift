import MultishellAppCore
import MultishellCore
import SwiftUI

/// A page on the panel's header: a glyph, underlined while chosen, named in a
/// tooltip while the pointer rests on it.
struct FilesPanelModeTab<Glyph: View>: View {
  private static var underlineHeight: Double { 2 }
  private static var underlineInset: Double { 7 }

  let model: AppModel
  let mode: FilesPanelMode
  let name: String
  let theme: Theme
  @ViewBuilder let glyph: () -> Glyph

  private var isSelected: Bool { model.shownFilesPanelMode == mode }

  var body: some View {
    Button {
      model.setFilesPanelMode(mode)
    } label: {
      glyph()
        .frame(width: UIMetrics.headerGlyphButtonSide, height: UIMetrics.headerGlyphButtonSide)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(name)
    .foregroundStyle(isSelected ? theme.header.text : theme.header.textTertiary)
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
