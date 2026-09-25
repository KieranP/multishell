import MultishellCore

/// What the last report about a key said beyond its state. It carries the
/// state it arrived with, so a note outlives no engine signal that moves it.
struct SessionNote: Equatable, Sendable {
  let state: SessionState
  let message: String?
  /// Seconds the finished command ran, where the source counted them.
  let duration: Double?

  init(state: SessionState, message: String? = nil, duration: Double? = nil) {
    self.state = state
    self.message = message
    self.duration = duration
  }

  /// The note as it applies to `state`, or `nil` where it describes
  /// something the pane has since stopped doing.
  func matching(_ state: SessionState?) -> SessionNote? {
    self.state == state ? self : nil
  }
}
