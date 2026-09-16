import Foundation

/// The lines a socket server handed its callback, read back on the test's
/// own thread.
public final class LineRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var lines: [String] = []

  public init() {}

  public func record(_ line: String) { lock.withLock { lines.append(line) } }
  public var received: [String] { lock.withLock { lines } }
}
