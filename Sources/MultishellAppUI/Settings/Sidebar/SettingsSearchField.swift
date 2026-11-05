import SwiftUI

/// The search field atop the settings sidebar: a grey well, no border, as the
/// sidebar's own controls are drawn. Escape empties it.
struct SettingsSearchField: View {
  @Binding var text: String

  var body: some View {
    TextField(
      t("settings.search"),
      text: $text,
      prompt: Text(t("settings.search")).foregroundStyle(SettingsColors.secondaryText),
    )
    .textFieldStyle(.plain)
    .font(.system(size: UIMetrics.settingsSidebarControlFontSize))
    .padding(.horizontal, 9)
    .padding(.vertical, 6)
    .background(SettingsColors.well, in: .rect(cornerRadius: UIMetrics.settingsSidebarWellRadius))
    .onExitCommand { text = "" }
  }
}
