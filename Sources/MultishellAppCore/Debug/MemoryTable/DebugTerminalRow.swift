/// The first line under an expanded tab: what its panes' terminals hold,
/// and its Total with the shells drawn under it.
public struct DebugTerminalRow: Sendable, Equatable, DebugSelfAndTotalMemory {
  public let selfMemory: UInt64
  public let totalMemory: UInt64
}
