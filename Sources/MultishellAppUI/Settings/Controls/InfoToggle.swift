import SwiftUI

struct InfoToggle: View {
  let label: String
  let info: String
  @Binding var isOn: Bool
  /// Off greys the switch alone: the (i) still opens, to say why.
  let isSwitchEnabled: Bool

  var body: some View {
    // The row's own Toggle stays enabled for the (i), so a greyed switch takes no write.
    Toggle(isOn: isSwitchEnabled ? $isOn : .constant(isOn)) { InfoLabel(label, info: info) }
      .toggleStyle(SettingsToggleStyle(isSwitchEnabled: isSwitchEnabled))
  }

  init(_ label: String, info: String, isOn: Binding<Bool>, isSwitchEnabled: Bool = true) {
    self.label = label
    self.info = info
    _isOn = isOn
    self.isSwitchEnabled = isSwitchEnabled
  }
}
