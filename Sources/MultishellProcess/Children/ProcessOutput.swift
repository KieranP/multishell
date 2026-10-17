import Foundation

public struct ProcessOutput: Sendable {
  /// As the child wrote it, for output that may not be UTF-8: a file's text.
  public let standardOutputBytes: Data
  let standardError: String
  public let status: Int32
  /// Set when this side ended the child: the timeout ran out, or the
  /// caller's `ProcessStopper` was used. `status` is then the signal's.
  let stopReason: ProcessStopReason?

  /// Decoded as UTF-8, a malformed byte read as U+FFFD.
  public var standardOutput: String { String(decoding: standardOutputBytes, as: UTF8.self) }

  public var succeeded: Bool { status == 0 }
}
