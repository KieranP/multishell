import Synchronization

/// Lines recorded from whatever thread they arrive on, read back on the
/// test's own.
public final class LineRecorder: Sendable {
  private let lines = Mutex<[String]>([])

  public init() {}

  public func record(_ line: String) { lines.withLock { $0.append(line) } }
  public var received: [String] { lines.withLock { $0 } }
}
