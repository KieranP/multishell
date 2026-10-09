import Synchronization

/// Where a run puts its child's lifetime usage as the child exits, for a
/// caller that asks: the read costs a syscall a child, so no other run pays it.
public final class ExitUsageProbe: Sendable {
  private let recorded = Mutex<ExitUsage?>(nil)

  /// `nil` until the child exits, or where the kernel would not say.
  public var usage: ExitUsage? { recorded.withLock { $0 } }

  public init() {}

  func record(_ usage: ExitUsage?) {
    recorded.withLock { $0 = usage }
  }
}
