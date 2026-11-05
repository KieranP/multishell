import SwiftUI

/// A section of a project's settings beside the global values they override,
/// under a heading naming the columns.
struct OverrideTable<Rows: View>: View {
  let title: String
  @ViewBuilder let rows: () -> Rows

  var body: some View {
    SettingsGroup {
      OverrideColumns {
        Text(title)
      } global: {
        Text(t("project.column-global"))
      } override: {
        Text(t("project.column-override"))
      }
      .font(.system(size: UIMetrics.settingsSmallTextSize, weight: .semibold))
      .foregroundStyle(.secondary)
      .accessibilityAddTraits(.isHeader)
      rows()
    }
  }

  init(_ title: String = "", @ViewBuilder rows: @escaping () -> Rows) {
    self.title = title
    self.rows = rows
  }
}
