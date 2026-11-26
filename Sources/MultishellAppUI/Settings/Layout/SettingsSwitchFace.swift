import SwiftUI

/// What `SettingsSwitchStyle` draws, a view of its own to read whether the switch
/// is enabled, which a style's body cannot: disabled, it dims as the buttons do.
struct SettingsSwitchFace<Label: View>: View {
  @Binding var isOn: Bool
  /// Hidden, but still what VoiceOver names the switch by.
  let label: Label

  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    Toggle(isOn: $isOn) { label }
      .labelsHidden()
      .toggleStyle(.switch)
      .controlSize(.small)
      .opacity(isEnabled ? 1 : UIMetrics.settingsDisabledOpacity)
  }
}
