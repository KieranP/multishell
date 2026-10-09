import Synchronization

/// Values recorded from whatever thread they arrive on, read back on the
/// test's own.
public final class Recorder<Value: Sendable>: Sendable {
  private let values = Mutex<[Value]>([])
  public var received: [Value] { values.withLock { $0 } }

  public init() {}

  public func record(_ value: Value) { values.withLock { $0.append(value) } }
  public func clear() { values.withLock { $0 = [] } }
}
