import SwiftUI

/// A value computed from the settings and shown live: a resolved path, an
/// example branch name. Help text goes behind an `InfoButton` instead.
struct SettingsCaption: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: UIMetrics.settingsSmallTextSize))
      .foregroundStyle(SettingsColors.secondaryText)
      .fixedSize(horizontal: false, vertical: true)
      .containerValue(\.isSettingsRowCaption, true)
  }

  init(_ text: String) { self.text = text }
}
