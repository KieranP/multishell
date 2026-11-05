import SwiftUI

/// The band atop the settings page, where the hidden title bar leaves room:
/// the page, the part shown, and whose settings they are.
struct SettingsPageHeader: View {
  let title: String
  let part: String?
  let caption: String

  var body: some View {
    HStack(spacing: 6) {
      Text(title)
        .font(.system(size: UIMetrics.settingsHeaderTitleSize, weight: .semibold))
      if let part {
        Text(t("settings.part-crumb", part))
          .font(.system(size: UIMetrics.settingsHeaderTitleSize))
          .foregroundStyle(SettingsColors.secondaryText)
      }
      Spacer(minLength: 12)
      Text(caption)
        .font(.system(size: UIMetrics.settingsSmallTextSize))
        .foregroundStyle(SettingsColors.secondaryText)
        .lineLimit(1)
        .truncationMode(.head)
    }
    .padding(.horizontal, UIMetrics.settingsHeaderSideInset)
    .frame(height: UIMetrics.settingsHeaderHeight)
    .background(SettingsColors.bar)
    .overlay(alignment: .bottom) {
      SettingsColors.rule.frame(height: UIMetrics.settingsRuleThickness)
    }
    .titleBarDoubleClick()
  }
}
