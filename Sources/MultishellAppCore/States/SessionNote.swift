import MultishellCore

/// What the last report about a key said beyond its state.
///
/// It carries the state it arrived with, so a note is shown only while it
/// still describes what the pane is doing: an engine signal can move a pane
/// from Waiting to Done without a report, and "Permission to run rm -rf" on
/// a finished pane would be a lie no later report has corrected yet.
public struct SessionNote: Equatable, Sendable {
  public let state: SessionState
  public let message: String?
  /// Seconds the finished command ran, where the source counted them.
  public let duration: Double?

  public init(state: SessionState, message: String? = nil, duration: Double? = nil) {
    self.state = state
    self.message = message
    self.duration = duration
  }

  /// The note as it applies to `state`, or `nil` where it describes
  /// something the pane has since stopped doing.
  public func describing(_ state: SessionState?) -> SessionNote? {
    self.state == state ? self : nil
  }
}
