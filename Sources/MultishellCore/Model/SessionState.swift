import Foundation

/// What a terminal's occupant last said about itself.
///
/// Runtime only, kept in the GUI beside the live sessions; a state describes
/// a process, and the workspace describes what should exist. `idle` is the
/// absence of a state and is never stored, only reported to clear one.
public enum SessionState: String, Codable, Hashable, Sendable, CaseIterable {
  case idle
  /// An agent or a command is working. About the process: stays while the
  /// tab is shown, clears on the next report or when the process is gone.
  case running
  /// Waiting for the user: a permission prompt, a question. About the
  /// agent: a question the user has seen but not answered is still waiting,
  /// so only the source clears it.
  case attention
  /// Finished since the tab was last shown. About the user: showing the tab
  /// clears it, as the activity dot always has.
  case done
  /// Finished badly since the tab was last shown: a command that exited
  /// non-zero, a turn that failed. Unlike Done it survives being looked at,
  /// and clears the way Waiting does: a failure is something to act on, and
  /// a glance is not acting.
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

  /// Whether looking is enough to clear it. Done alone: it says a thing
  /// happened, and seeing it is the whole of what the user owes it. Failed
  /// asks to be dealt with, so it keeps the dot red until the source reports
  /// again or the user clears it by hand. Not quite Waiting's rule, which it
  /// borrows the look half of: a dead process takes a Waiting dot with it
  /// and leaves a Failed one standing, a failure having outlived the thing
  /// that failed. The banner goes either way, an interruption being spent
  /// once it has interrupted.
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
