import Synchronization

/// The lines a socket server handed its callback, read back on the test's
/// own thread.
public final class LineRecorder: Sendable {
  private let lines = Mutex<[String]>([])

  public init() {}

  public func record(_ line: String) { lines.withLock { $0.append(line) } }
  public var received: [String] { lines.withLock { $0 } }
}
