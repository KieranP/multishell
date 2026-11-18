// Declared bottom to top, the order the CPU tile stacks its bands in.
// swiftlint:disable sorted_enum_cases
/// Which part of the app a thread works for, as the CPU tile splits it.
public enum DebugThreadGroup: Sendable, Hashable {
  case main
  /// Each terminal's: its renderer, CoreText release and display link threads,
  /// its pty reader, gatherer and writer, its search.
  case terminals
  case other

  /// The names of the threads a terminal starts: Ghostty's own, and CoreVideo's
  /// for its display link, the app's own frame link starting no such thread.
  private static let terminalThreadNames: Set<String> = [
    "renderer", "cf_release", "CVDisplayLink", "io", "io-reader", "io-gather", "search",
  ]

  /// Its band on the CPU tile, whose colour its rows in CPU Breakdown share.
  public var series: DebugSeries {
    switch self {
    case .main: .mainThread
    case .terminals: .terminalThreads
    case .other: .otherThreads
    }
  }

  static func of(threadNamed name: String, isMain: Bool) -> Self {
    if isMain { return .main }
    return terminalThreadNames.contains(name) ? .terminals : .other
  }
}
// swiftlint:enable sorted_enum_cases
