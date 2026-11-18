/// The threads one row of CPU Breakdown adds up: those sharing a name and a
/// group, so an unnamed main thread stays apart from the unnamed workers.
public struct DebugThreadKey: Sendable, Hashable {
  let group: DebugThreadGroup
  /// Empty where the threads were never named.
  let name: String
}
