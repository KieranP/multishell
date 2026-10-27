import Foundation

public struct ProcessOutput: Sendable {
  /// As the child wrote it, for output that may not be UTF-8: a file's text.
  public let standardOutputBytes: Data
  public let standardError: String
  public let status: Int32
  /// Set when this side ended the child: the timeout ran out, or the
  /// caller's `ProcessStopper` was used. `status` is then the signal's.
  public let stopReason: ProcessStopReason?

  /// Decoded as UTF-8, a malformed byte read as U+FFFD.
  public var standardOutput: String { String(decoding: standardOutputBytes, as: UTF8.self) }

  public var succeeded: Bool { status == 0 }

  /// Itself where the child exited 0, else the `ProcessFailure` that exit is.
  public func requiringSuccess(of executable: URL, arguments: [String]) throws -> Self {
    guard succeeded else {
      throw ProcessFailure(
        executable: executable.lastPathComponent,
        arguments: arguments,
        status: status,
        message: standardError.trimmingCharacters(in: .whitespacesAndNewlines),
        stopReason: stopReason,
      )
    }
    return self
  }
}
