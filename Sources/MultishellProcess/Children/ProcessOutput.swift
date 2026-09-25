public struct ProcessOutput: Sendable {
  public let standardOutput: String
  public let standardError: String
  public let status: Int32
  /// Set when this side ended the child: the timeout ran out, or the
  /// caller's `ProcessStopper` was used. `status` is then the signal's.
  public let stop: ProcessStop?

  init(
    standardOutput: String, standardError: String, status: Int32, stop: ProcessStop? = nil
  ) {
    self.standardOutput = standardOutput
    self.standardError = standardError
    self.status = status
    self.stop = stop
  }

  public var succeeded: Bool { status == 0 }
}
