/// A row of CPU Breakdown under its group: the threads sharing a name, what
/// they spent over the range, and that as a share of one core.
public struct DebugThreadRow: Sendable, Equatable, Identifiable, DebugThreadFigures,
  DebugSortableRow
{
  let key: DebugThreadKey
  let tally: DebugThreadTally
  public let meanPercent: Double

  public var id: DebugThreadKey { key }
  public var threadCount: Int { tally.threadCount }
  public var cpuTime: Duration { tally.cpuTime }
}
