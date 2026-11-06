import MultishellAppCore
import SwiftUI

/// A row of the settings sidebar: a page on its coloured tile, or a part of a
/// split page, its title in line with the pages' titles above it.
struct SettingsSidebarRow: View {
  let title: String
  /// The page whose tile leads the row; `nil` for a part.
  let page: SettingsPage?
  let isSelected: Bool
  let select: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: select) {
      HStack(spacing: UIMetrics.settingsSidebarRowSpacing) {
        if let page {
          SettingsTile(
            side: UIMetrics.settingsPageTileSide,
            radius: UIMetrics.settingsPageTileRadius,
            color: page.tileColor,
          ) {
            SettingsPageGlyph(page: page)
              .frame(
                width: UIMetrics.settingsSidebarGlyphSide,
                height: UIMetrics.settingsSidebarGlyphSide,
              )
          }
        }
        Text(title)
          .font(.system(size: page == nil ? UIMetrics.settingsSidebarControlFontSize : 13))
          .foregroundStyle(textStyle)
          .lineLimit(1)
        Spacer(minLength: 0)
      }
      .padding(.vertical, 4)
      .padding(
        .leading,
        page == nil ? UIMetrics.settingsPartIndent : UIMetrics.settingsSidebarRowSideInset,
      )
      .padding(.trailing, UIMetrics.settingsSidebarRowSideInset)
      .frame(minHeight: UIMetrics.settingsPageTileSide + 8)
      .background(fill, in: .rect(cornerRadius: UIMetrics.settingsControlRadius))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .tracksHover($isHovered)
    .selectableButtonTraits(isSelected: isSelected)
  }

  private var fill: Color {
    if isSelected { return .accentColor }
    return isHovered ? SettingsColors.well : .clear
  }

  private var textStyle: Color {
    if isSelected { return .white }
    return page == nil ? SettingsColors.secondaryText : .primary
  }
}
