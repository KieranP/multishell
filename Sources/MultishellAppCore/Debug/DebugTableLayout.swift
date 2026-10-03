/// How a debug table fits its width without scrolling: columns side by side,
/// or each row's numbers stacked under its name where the columns would not fit.
public enum DebugTableLayout: Sendable, Equatable {
  case columns
  case stacked

  /// What each table's columns need, in multiples of the body font size.
  public static let memoryTableColumnsWidthInEms = 46.0
  public static let gitTableColumnsWidthInEms = 60.0

  public static func of(width: Double, columnsWidthInEms ems: Double, fontSize: Double) -> Self {
    width >= ems * fontSize ? .columns : .stacked
  }
}
