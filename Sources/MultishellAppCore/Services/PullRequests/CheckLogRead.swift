import MultishellServices

/// What Send read of a failing check's log.
enum CheckLogRead: Equatable, Sendable {
  /// The tool's words for why it could not read it.
  case failed(String)
  /// A check from another CI, which the host's tool has no log of.
  case noLog
  case read(FailedCheckLog)
}
