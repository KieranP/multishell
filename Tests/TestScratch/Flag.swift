import Synchronization

/// A box for `withObservationTracking`, whose `@Sendable` callback can
/// neither capture a mutable local nor be trusted to run on one thread.
public final class Flag: Sendable {
  private let value = Atomic(false)

  public init() {}

  public var raised: Bool { value.load(ordering: .acquiring) }
  public func raise() { value.store(true, ordering: .releasing) }
}
