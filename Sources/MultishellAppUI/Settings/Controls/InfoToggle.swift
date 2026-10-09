import SwiftUI

struct InfoToggle: View {
  let title: String
  let info: String
  @Binding var isOn: Bool

  var body: some View {
    Toggle(isOn: $isOn) { InfoLabel(title, info: info) }
  }

  init(_ title: String, info: String, isOn: Binding<Bool>) {
    self.title = title
    self.info = info
    _isOn = isOn
  }
}
