import SwiftUI

/// A settings row's switch: its label on the left, a small switch on the right.
struct SettingsToggleStyle: ToggleStyle {
  /// Off greys the switch alone, leaving the label's (i) to say why.
  var isSwitchEnabled = true

  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: UIMetrics.settingsRowSpacing) {
      configuration.label
      Spacer(minLength: 0)
      Toggle(isOn: configuration.$isOn) { configuration.label }
        .toggleStyle(SettingsSwitchStyle())
        .disabled(!isSwitchEnabled)
    }
  }
}
