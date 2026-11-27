import SwiftUI

extension View {
  /// A settings table's row of column titles, heading the card it opens.
  func settingsColumnHeadings() -> some View {
    font(.system(size: UIMetrics.settingsSmallTextSize, weight: .semibold))
      .foregroundStyle(SettingsColors.secondaryText)
      .accessibilityAddTraits(.isHeader)
  }
}
