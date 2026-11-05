import SwiftUI

/// The mockup's small switch, alone: an override's control, and the right end
/// of `SettingsToggleStyle`'s row.
struct SettingsSwitchStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    Toggle(isOn: configuration.$isOn) { configuration.label }
      .labelsHidden()
      .toggleStyle(.switch)
      .controlSize(.small)
  }
}
