import MultishellCore
import SwiftUI

extension View {
  /// A debug table row: the table's inset and a hairline above it.
  func debugTableRow(_ theme: Theme, verticalPadding: Double = 5) -> some View {
    padding(.horizontal, UIMetrics.debugTableInset)
      .padding(.vertical, verticalPadding)
      .hairline(.top, theme)
  }

  /// Faintly filled while the pointer is over it; see `DebugTableRowHighlight`.
  func highlightsOnHover(_ theme: Theme) -> some View {
    modifier(DebugTableRowHighlight(theme: theme))
  }

  /// A column title right-aligned over its numbers, wrapping rather than
  /// widening the column.
  func debugColumnTitle(width: Double) -> some View {
    multilineTextAlignment(.trailing)
      .fixedSize(horizontal: false, vertical: true)
      .frame(width: width, alignment: .trailing)
  }

  /// A debug table's column titles, in faint caption type over the rows.
  func debugTableHeader(
    _ theme: Theme, _ metrics: UIMetrics, leadingInset: Double = UIMetrics.debugTableInset
  ) -> some View {
    font(.system(size: metrics.caption))
      .foregroundStyle(theme.textTertiary)
      .padding(.leading, leadingInset)
      .padding(.trailing, UIMetrics.debugTableInset)
      .padding(.bottom, 4)
  }
}
