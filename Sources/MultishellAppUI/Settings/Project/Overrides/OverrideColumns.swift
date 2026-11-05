import SwiftUI

/// The three columns of a project's settings table, at one width for its
/// heading and every row, so each column lines up down the table.
struct OverrideColumns<Setting: View, Global: View, Override: View>: View {
  @ViewBuilder let setting: () -> Setting
  @ViewBuilder let global: () -> Global
  @ViewBuilder let override: () -> Override

  var body: some View {
    HStack(spacing: UIMetrics.settingsColumnSpacing) {
      setting()
        .frame(maxWidth: .infinity, alignment: .leading)
      global()
        .frame(width: UIMetrics.settingsGlobalColumnWidth, alignment: .leading)
      HStack(spacing: 6) { override() }
        .frame(width: UIMetrics.settingsOverrideColumnWidth, alignment: .leading)
    }
  }
}
