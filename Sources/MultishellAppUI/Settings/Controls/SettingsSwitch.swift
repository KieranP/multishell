import SwiftUI

/// The mockup's small switch on its own, an override's control, its label
/// read by VoiceOver only.
struct SettingsSwitch: View {
  let label: String
  @Binding var isOn: Bool

  var body: some View {
    Toggle(label, isOn: $isOn).toggleStyle(SettingsSwitchStyle())
  }
}
