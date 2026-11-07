import MultishellCore

extension SessionState {
  /// Whether this finish says nothing past the one a program announced as its
  /// hold ended: any Done, or a Failed after a Failed. See agents/program-status.md.
  func repeatsFinish(announced: SessionState) -> Bool {
    self == .done || self == announced
  }
}
