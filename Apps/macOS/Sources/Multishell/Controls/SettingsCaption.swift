import SwiftUI

/// A value computed from the settings and shown live: a resolved path, an
/// example branch name. Help text goes behind an `InfoButton` instead.
struct SettingsCaption: View {
  let text: String

  init(_ text: String) { self.text = text }

  var body: some View {
    Text(text)
      .font(.system(size: 11))
      .foregroundStyle(.tertiary)
      .fixedSize(horizontal: false, vertical: true)
  }
}
