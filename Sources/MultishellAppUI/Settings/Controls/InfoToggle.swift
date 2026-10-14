import SwiftUI

struct InfoToggle: View {
  let label: String
  let info: String
  @Binding var isOn: Bool

  var body: some View {
    Toggle(isOn: $isOn) { InfoLabel(label, info: info) }
  }

  init(_ label: String, info: String, isOn: Binding<Bool>) {
    self.label = label
    self.info = info
    _isOn = isOn
  }
}
