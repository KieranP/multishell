/// A child that exited non-zero. `message` is its stderr, so git's own words
/// reach the alert rather than a description of this struct.
public struct ProcessFailure: Error, CustomStringConvertible {
  public let executable: String
  public let arguments: [String]
  public let status: Int32
  public let message: String
  /// Why the child did not finish on its own, when it did not.
  public let stop: ProcessStop?

  public init(
    executable: String, arguments: [String], status: Int32, message: String,
    stop: ProcessStop? = nil
  ) {
    self.executable = executable
    self.arguments = arguments
    self.status = status
    self.message = message
    self.stop = stop
  }

  public var description: String {
    "\(executable) \(arguments.joined(separator: " ")) failed (\(status)): \(message)"
  }
}
