/// What a sendable row draws at its trailing edge: a checkbox, or the sent bubble.
public enum HandoffItemState: Equatable, Sendable {
  case checked
  /// Sent to the agent named, its tooltip and spoken label.
  case sent(agentName: String)
  case unchecked

  var isChecked: Bool { self == .checked }

  var isSent: Bool {
    if case .sent = self { true } else { false }
  }
}
