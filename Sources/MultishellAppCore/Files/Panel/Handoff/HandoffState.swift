import MultishellCore
import Observation

/// What Send holds, by worktree. Its own observable, so a log read's count
/// redraws the foot and not every checkbox; see services/send-feedback.md.
@Observable
@MainActor
final class HandoffState {
  /// The agent pane each worktree's picker was set to, shared by Review and the
  /// PR and CI pages.
  var recipientPicks: [Worktree.ID: TerminalSession.ID] = [:]
  /// Each worktree's checkboxes and what each Send carried.
  var choices: [Worktree.ID: HandoffChoices] = [:]
  /// What each worktree's last Send from the PR or CI page said, per page.
  var receipts: [Worktree.ID: [ServicePage: String]] = [:]
  /// Each worktree's PR page Send with checks, while one is under way.
  var sendPhases: [Worktree.ID: HandoffSendPhase] = [:]
  /// Why each page's last Send sent nothing, until the next pick or Send there.
  var misses: [Worktree.ID: [ServicePage: String]] = [:]
}
