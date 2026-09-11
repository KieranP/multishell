import MultishellCore
import MultishellGitKit

/// The create or remove running on each worktree, and who owns an entry where
/// two meet: the removal takes it, and the hook's later result is dropped.
public struct WorktreeOperations: Equatable, Sendable {
  public private(set) var operations: [Worktree.ID: WorktreeOperation] = [:]

  public init() {}

  public subscript(id: Worktree.ID) -> WorktreeOperation? { operations[id] }

  public var isEmpty: Bool { operations.isEmpty }

  /// Something is running on the worktree, or has failed and not been
  /// dismissed. Nothing starts a shell there until then.
  public func isBusy(_ id: Worktree.ID) -> Bool {
    operations[id] != nil
  }

  /// A stage starts. Whatever was there gives way: the newer operation owns
  /// the entry from here on.
  public mutating func begin(_ step: WorktreeOperation.Step, on id: Worktree.ID) {
    operations[id] = WorktreeOperation(step)
  }

  /// A running operation reached its next stage. Nothing once it has
  /// failed: the pane keeps saying what went wrong.
  public mutating func advance(to step: WorktreeOperation.Step, on id: Worktree.ID) {
    guard operations[id]?.isRunning == true else { return }
    operations[id] = WorktreeOperation(step)
  }

  /// The stage failed with the worktree still there, so the pane shows
  /// `message` until dismissed. Returns whether that stage was running.
  @discardableResult
  public mutating func fail(
    _ step: WorktreeOperation.Step, on id: Worktree.ID, message: String, timedOut: Bool = false
  )
    -> Bool
  {
    guard owns(step, id) else { return false }
    operations[id] = WorktreeOperation(step, failure: message, timedOut: timedOut)
    return true
  }

  /// The stage `step` ended. Clears the entry only while that stage is the
  /// one running; returns whether it was.
  @discardableResult
  public mutating func finish(_ step: WorktreeOperation.Step, on id: Worktree.ID) -> Bool {
    guard owns(step, id) else { return false }
    operations[id] = nil
    return true
  }

  /// The user's Dismiss. A failed entry goes and is returned so the caller
  /// can act on what it was; a running one stays.
  public mutating func dismiss(_ id: Worktree.ID) -> WorktreeOperation? {
    guard let operation = operations[id], !operation.isRunning else { return nil }
    operations[id] = nil
    return operation
  }

  /// Whatever is there goes: after an alert about a stage that ended with
  /// the worktree gone or put back.
  public mutating func clear(_ id: Worktree.ID) {
    operations[id] = nil
  }

  private func owns(_ step: WorktreeOperation.Step, _ id: Worktree.ID) -> Bool {
    guard let current = operations[id] else { return false }
    return current.isRunning && current.step == step
  }
}
