import Foundation

/// A box for `withObservationTracking`, whose `@Sendable` callback can
/// neither capture a mutable local nor be trusted to run on one thread.
public final class Flag: @unchecked Sendable {
  private let lock = NSLock()
  private var value = false

  public init() {}

  public var raised: Bool { lock.withLock { value } }
  public func raise() { lock.withLock { value = true } }
}
