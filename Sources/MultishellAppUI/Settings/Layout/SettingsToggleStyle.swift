import SwiftUI

/// A settings row's switch: its label on the left, a small switch on the right.
struct SettingsToggleStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: UIMetrics.settingsRowSpacing) {
      configuration.label
      Spacer(minLength: 0)
      Toggle(isOn: configuration.$isOn) { configuration.label }
        .toggleStyle(SettingsSwitchStyle())
    }
  }
}
