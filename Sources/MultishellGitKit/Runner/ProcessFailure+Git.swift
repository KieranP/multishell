import MultishellProcess

extension ProcessFailure {
  /// A failure git did not report itself, so status 0: an answer that proves
  /// nothing, or a run stopped after git finished.
  static func git(
    _ arguments: [String], message: String, stop: ProcessStop? = nil
  ) -> ProcessFailure {
    ProcessFailure(
      executable: "git", arguments: arguments, status: 0, message: message, stop: stop)
  }
}
