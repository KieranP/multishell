import MultishellCore

/// One row of the Memory by tab table as the panel draws it: the app, a tab,
/// what no tab runs, or the total.
public struct DebugMemoryRow: Sendable, Equatable, Identifiable {
  public enum Source: Sendable, Hashable {
    case app
    case tab(TerminalTab.ID)
    case unattributed
    case total
  }

  public let source: Source
  public let title: String
  /// The worktree for a tab, what the row counts for the others.
  public let subtitle: String
  /// `nil` for a tab the engine could not place, as are its memories, and
  /// for the total row, which has no share of its own.
  let processCount: Int?
  let selfMemory: UInt64?
  let totalMemory: UInt64?
  /// This row's Total as a fraction of the heaviest row's; 0 on the Total row.
  public let barFraction: Double
  /// A tab's terminals, listed first when it opens; `nil` for other rows.
  public let terminalRow: DebugTerminalRow?
  public let processRows: [DebugProcessRow]

  public var id: Source { source }
  public var isTotal: Bool { source == .total }

  /// Its tree depth, one level further in under a Terminal row, since the
  /// shells run in it.
  public func indentLevel(of process: DebugProcessRow) -> Int {
    (terminalRow == nil ? 0 : 1) + process.depth
  }

  public func disclosure(isExpanded: Bool) -> DebugRowDisclosure {
    guard terminalRow != nil || !processRows.isEmpty else { return .notExpandable }
    return isExpanded ? .expanded : .collapsed
  }
}
