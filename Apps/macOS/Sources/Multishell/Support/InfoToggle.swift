import SwiftUI

/// A toggle with its (i) after its title.
struct InfoToggle: View {
  let title: String
  let info: String
  @Binding var isOn: Bool

  init(_ title: String, info: String, isOn: Binding<Bool>) {
    self.title = title
    self.info = info
    _isOn = isOn
  }

  var body: some View {
    Toggle(isOn: $isOn) { InfoLabel(title, info: info) }
  }
}
