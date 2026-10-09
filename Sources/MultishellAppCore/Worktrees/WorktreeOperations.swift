import MultishellCore

/// The create or remove running on each worktree, and who owns an entry where
/// two meet: the removal takes it, and the hook's later result is dropped.
public struct WorktreeOperations: Equatable, Sendable {
  private var operations: [Worktree.ID: WorktreeOperation] = [:]

  /// Whether nothing is held, for the tests.
  var isEmpty: Bool { operations.isEmpty }

  /// Something is running on the worktree, or has failed and not been
  /// dismissed. Nothing starts a shell there until then.
  func isBusy(_ id: Worktree.ID) -> Bool {
    operations[id] != nil
  }

  /// A stage is writing there now. A failed one is not: nothing writes
  /// until the Dismiss.
  func isRunning(_ id: Worktree.ID) -> Bool {
    operations[id]?.isRunning == true
  }

  /// A stage starts. Whatever was there gives way: the newer operation owns
  /// the entry from here on.
  mutating func begin(_ stage: WorktreeOperation.Stage, on id: Worktree.ID) {
    operations[id] = WorktreeOperation(stage)
  }

  /// A running operation reached its next stage. Nothing once it has
  /// failed: the pane keeps saying what went wrong.
  mutating func advance(to stage: WorktreeOperation.Stage, on id: Worktree.ID) {
    guard operations[id]?.isRunning == true else { return }
    operations[id] = WorktreeOperation(stage)
  }

  /// The stage failed with the worktree still there, so the pane shows
  /// `message` until dismissed. Returns whether that stage was running.
  @discardableResult
  mutating func fail(
    _ stage: WorktreeOperation.Stage,
    on id: Worktree.ID,
    message: String,
    didTimeOut: Bool = false,
  )
    -> Bool
  {
    guard owns(stage, id) else { return false }
    operations[id] = WorktreeOperation(stage, failure: message, didTimeOut: didTimeOut)
    return true
  }

  /// `stage` ended. Clears the entry only while it is the one running;
  /// returns whether it was.
  @discardableResult
  mutating func finish(_ stage: WorktreeOperation.Stage, on id: Worktree.ID) -> Bool {
    guard owns(stage, id) else { return false }
    operations[id] = nil
    return true
  }

  /// The user's Dismiss. A failed entry goes and is returned so the caller
  /// can act on what it was; a running one stays.
  mutating func dismiss(_ id: Worktree.ID) -> WorktreeOperation? {
    guard let operation = operations[id], !operation.isRunning else { return nil }
    operations[id] = nil
    return operation
  }

  /// Whatever is there goes: after an alert about a stage that ended with
  /// the worktree gone or put back.
  mutating func clear(_ id: Worktree.ID) {
    operations[id] = nil
  }

  private func owns(_ stage: WorktreeOperation.Stage, _ id: Worktree.ID) -> Bool {
    guard let current = operations[id] else { return false }
    return current.isRunning && current.stage == stage
  }

  public subscript(id: Worktree.ID) -> WorktreeOperation? { operations[id] }
}
