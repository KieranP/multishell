import SwiftUI

/// The mockup's small switch, alone: an override's control, and the right end
/// of `SettingsToggleStyle`'s row.
struct SettingsSwitchStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    SettingsSwitchFace(isOn: configuration.$isOn, label: configuration.label)
  }
}
