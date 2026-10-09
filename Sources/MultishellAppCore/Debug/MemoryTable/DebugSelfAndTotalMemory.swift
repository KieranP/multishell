/// A nested row under an expanded row of the Memory by tab table: what it holds
/// itself, and with everything drawn under it.
public protocol DebugSelfAndTotalMemory {
  var selfMemory: UInt64 { get }
  var totalMemory: UInt64 { get }
}
