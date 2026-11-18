/// A top row of CPU Breakdown: one group's threads added up, as the CPU tile's
/// band for it, opening to list them by name (debug-tools.md).
public struct DebugThreadGroupRow: Sendable, Equatable, Identifiable, DebugThreadFigures,
  DebugSortableRow
{
  public let group: DebugThreadGroup
  public let threads: [DebugThreadRow]
  /// The most of the group's threads any one sample saw, not its names'
  /// peaks added up, which can fall in different seconds.
  public let threadCount: Int

  public var id: DebugThreadGroup { group }
  public var cpuTime: Duration { threads.reduce(.zero) { $0 + $1.cpuTime } }
  public var meanPercent: Double { threads.reduce(0) { $0 + $1.meanPercent } }

  /// The main thread is one thread, which its row already is.
  public func disclosure(isExpanded: Bool) -> DebugRowDisclosure {
    guard group != .main else { return .notExpandable }
    return isExpanded ? .expanded : .collapsed
  }
}
