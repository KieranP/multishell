/// A run that did not succeed: a non-zero exit, a stop, or an answer that
/// proves nothing. `message` is what an alert shows: stderr, a script's output, or the app's words.
public struct ProcessFailure: Error, CustomStringConvertible {
  public let executable: String
  public let arguments: [String]
  public let status: Int32
  public let message: String
  /// Why the child did not finish on its own, when it did not.
  public let stopReason: ProcessStopReason?

  public init(
    executable: String, arguments: [String], status: Int32, message: String,
    stopReason: ProcessStopReason? = nil
  ) {
    self.executable = executable
    self.arguments = arguments
    self.status = status
    self.message = message
    self.stopReason = stopReason
  }

  public var description: String {
    "\(executable) \(arguments.joined(separator: " ")) failed (\(status)): \(message)"
  }
}
