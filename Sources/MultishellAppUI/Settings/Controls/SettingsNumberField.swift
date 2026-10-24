import SwiftUI

/// A whole number typed into a settings row. Never grouped, a port read as
/// "3,000" being no port.
struct SettingsNumberField: View {
  private let title: String
  @Binding private var value: Int

  var body: some View {
    TextField(title, value: $value, format: .number.grouping(.never))
      .frame(width: 60)
      .multilineTextAlignment(.trailing)
  }

  init(_ title: String, value: Binding<Int>) {
    self.title = title
    self._value = value
  }
}
