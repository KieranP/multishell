import SwiftUI

/// The search field atop the settings sidebar: a grey well, no border, as the
/// sidebar's own controls are drawn. Escape empties it.
struct SettingsSearchField: View {
  @Binding var text: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: UIMetrics.settingsSearchGlyphSize))
        .foregroundStyle(SettingsColors.secondaryText)
        .accessibilityHidden(true)
      TextField(
        t("settings.search"),
        text: $text,
        prompt: Text(t("settings.search")).foregroundStyle(SettingsColors.secondaryText),
      )
      .textFieldStyle(.plain)
      .font(.system(size: UIMetrics.settingsSidebarControlFontSize))
      .onExitCommand { text = "" }
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 6)
    .background(SettingsColors.well, in: .rect(cornerRadius: UIMetrics.settingsSidebarWellRadius))
  }
}
