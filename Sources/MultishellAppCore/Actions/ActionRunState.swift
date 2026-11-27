import Foundation

/// Where an action stands in one worktree: running from its own run, done or
/// failed from its tab's dot once it has ended.
enum ActionRunState: Equatable, Sendable {
  case done
  case failed
  /// No tab, or nothing of the action's own to show: never run this time, its
  /// end seen, or the shell after it busy with something else.
  case idle
  case running(since: Date)

  var isRunning: Bool {
    if case .running = self { return true }
    return false
  }
}
