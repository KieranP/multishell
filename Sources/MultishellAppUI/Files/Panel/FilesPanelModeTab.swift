import MultishellAppCore
import MultishellCore
import SwiftUI

/// Files or Git on the panel's header: a glyph, underlined while chosen.
struct FilesPanelModeTab: View {
  private static let underlineHeight: Double = 2
  private static let underlineInset: Double = 7

  let model: AppModel
  let mode: FilesPanelMode
  let symbol: String
  let title: String
  let theme: Theme

  private var isSelected: Bool { model.workspace.filesPanelMode == mode }

  var body: some View {
    PlainGlyphButton(help: title) {
      model.setFilesPanelMode(mode)
    } glyph: {
      HeaderGlyph(symbol: symbol)
    }
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
    .selectableButtonTraits(isSelected: isSelected)
  }
}
