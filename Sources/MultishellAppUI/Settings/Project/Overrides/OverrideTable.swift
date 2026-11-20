import SwiftUI

/// A section of a project's settings beside the global values they override, or of
/// commands beside their default keys, under a heading naming the columns.
struct OverrideTable<Rows: View>: View {
  let title: String
  let columnTitles: (global: String, override: String)
  @ViewBuilder let rows: () -> Rows

  var body: some View {
    SettingsGroup {
      OverrideColumns {
        Text(title)
      } global: {
        Text(columnTitles.global)
      } override: {
        Text(columnTitles.override)
      }
      .font(.system(size: UIMetrics.settingsSmallTextSize, weight: .semibold))
      .foregroundStyle(SettingsColors.secondaryText)
      .accessibilityAddTraits(.isHeader)
      rows()
    }
  }

  init(
    _ title: String = "",
    columnTitles: (global: String, override: String) = (
      t("project.column-global"), t("project.column-override"),
    ),
    @ViewBuilder rows: @escaping () -> Rows,
  ) {
    self.title = title
    self.columnTitles = columnTitles
    self.rows = rows
  }
}
