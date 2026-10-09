import MultishellProcess

extension ProcessFailure {
  /// A failure git did not report itself, so status 0: an answer that proves
  /// nothing, or a run stopped after git finished.
  static func unreportedByGit(
    _ arguments: [String],
    message: String,
    stopReason: ProcessStopReason? = nil,
  ) -> ProcessFailure {
    ProcessFailure(
      executable: "git",
      arguments: arguments,
      status: 0,
      message: message,
      stopReason: stopReason,
    )
  }
}
