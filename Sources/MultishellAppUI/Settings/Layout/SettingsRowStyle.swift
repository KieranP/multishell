import SwiftUI

/// A settings row's label on the left and its control on the right, the
/// control no wider than a field the mockup drew.
struct SettingsRowStyle: LabeledContentStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: UIMetrics.settingsRowSpacing) {
      configuration.label
      Spacer(minLength: 0)
      configuration.content
        .frame(maxWidth: UIMetrics.settingsControlMaxWidth, alignment: .trailing)
    }
  }
}
