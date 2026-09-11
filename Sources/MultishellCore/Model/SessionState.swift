import Foundation

/// What a terminal's occupant last said about itself. Runtime only; `idle`
/// is the absence of a state, reported only to clear one.
public enum SessionState: String, Codable, Hashable, Sendable, CaseIterable {
  case idle
  /// An agent or a command is working. About the process: stays while the
  /// tab is shown, clears on the next report or when the process is gone.
  case running
  /// Waiting for the user. A question seen but unanswered is still waiting,
  /// so only the source clears it.
  case attention
  /// Finished since the tab was last shown. About the user: showing the tab
  /// clears it, as the activity dot always has.
  case done
  /// Finished badly since the tab was last shown. Unlike Done it survives
  /// being looked at: a glance is not acting.
  case error

  /// A tab or worktree with several sessions shows the most urgent.
  public var urgency: Int {
    switch self {
    case .idle: 0
    case .done: 1
    case .running: 2
    case .error: 3
    case .attention: 4
    }
  }

  public var displayName: String {
    switch self {
    case .idle: t("state.idle")
    case .running: t("state.running")
    case .attention: t("state.attention")
    case .done: t("state.done")
    case .error: t("state.error")
    }
  }

  /// `nil` for idle, so a dictionary of states never holds an entry that
  /// means "no entry".
  public var stored: SessionState? {
    self == .idle ? nil : self
  }

  /// Done and Failed: about the user rather than about a process, so they
  /// outlive the thing that reported them.
  public var isFinished: Bool {
    self == .done || self == .error
  }

  /// Whether looking is enough to clear it: Done alone. See
  /// docs/design/agents.md for how Failed and Waiting part on a dead process.
  public var clearsWhenSeen: Bool { self == .done }

  /// What a foreground command's exit code says. A code above 128 is a
  /// signal, usually the user's own Ctrl+C, and is not a failure.
  public static func finished(exitCode: Int32?) -> SessionState {
    guard let exitCode, exitCode != 0, exitCode <= 128 else { return .done }
    return .error
  }

  public static func mostUrgent(_ states: some Sequence<SessionState>) -> SessionState? {
    states.max { $0.urgency < $1.urgency }?.stored
  }
}
