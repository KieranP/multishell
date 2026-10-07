public struct ProcessOutput: Sendable {
  public let standardOutput: String
  let standardError: String
  public let status: Int32
  /// Set when this side ended the child: the timeout ran out, or the
  /// caller's `ProcessStopper` was used. `status` is then the signal's.
  let stopReason: ProcessStopReason?

  public var succeeded: Bool { status == 0 }
}
