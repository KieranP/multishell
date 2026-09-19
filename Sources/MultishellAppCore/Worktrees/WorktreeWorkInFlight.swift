import MultishellCore
import MultishellProcess

/// What is running while a worktree is built, and the handles that stop it.
/// Never drawn: `WorktreeOperations` beside it is what the pane shows.
public struct WorktreeWorkInFlight: Sendable {
  private var setups: [Worktree.ID: Task<Void, Never>] = [:]
  private var stoppers: [Worktree.ID: ProcessStopper] = [:]
  /// Counted, not a set: two creates can name one path; see worktrees.md.
  private var claims: [Worktree.ID: Int] = [:]
  /// The pre-create hook and `git worktree add` under the sheet, which run
  /// before there is a worktree to key a handle by.
  private var creation: ProcessStopper?

  public init() {}

  /// The file lists and post-create hook still running on `id`, as one task,
  /// so a test can await it.
  func setup(of id: Worktree.ID) -> Task<Void, Never>? { setups[id] }

  public func stopper(of id: Worktree.ID) -> ProcessStopper? { stoppers[id] }

  /// Behind the pane's Cancel: a hook by signal, a file list between files.
  func stopStage(of id: Worktree.ID) {
    stoppers[id]?.stop()
  }

  /// The handle is installed before the task is made, so a Cancel clicked in
  /// between finds something to stop. Hence two calls and not one.
  public mutating func arm(_ stopper: ProcessStopper, on id: Worktree.ID) {
    stoppers[id] = stopper
  }

  public mutating func setSetup(_ setup: Task<Void, Never>, on id: Worktree.ID) {
    setups[id] = setup
  }

  /// The stop handle goes only where it is still `stopper`: a later stage on
  /// the worktree owns its own, and a removal drops no create's setup task.
  public mutating func disarm(_ id: Worktree.ID, stoppedBy stopper: ProcessStopper) {
    if stoppers[id] === stopper { stoppers[id] = nil }
  }

  /// A setup stage ended: its task and, if still its own, its stop handle.
  public mutating func end(_ id: Worktree.ID, stoppedBy stopper: ProcessStopper) {
    setups[id] = nil
    disarm(id, stoppedBy: stopper)
  }

  /// The sheet's Cancel while the pre-create hook or git runs.
  func cancelCreation() {
    creation?.stop()
  }

  /// Whether `stopper` is the create the sheet is showing. A step reported by
  /// an older one is dropped.
  public func isCreating(with stopper: ProcessStopper) -> Bool {
    creation === stopper
  }

  public mutating func beginCreation(with stopper: ProcessStopper) {
    creation = stopper
  }

  public mutating func endCreation() {
    creation = nil
  }

  /// A path is being checked out into. The caller has already found no
  /// worktree listed there; see `AppModel.claimConstruction`.
  public mutating func claim(_ id: Worktree.ID) {
    claims[id, default: 0] += 1
  }

  /// One claim let go, not the path: another create may still hold it.
  public mutating func release(_ id: Worktree.ID) {
    guard let count = claims[id], count > 1 else {
      claims[id] = nil
      return
    }
    claims[id] = count - 1
  }

  func isClaimed(_ id: Worktree.ID) -> Bool { claims[id] != nil }

  /// The paths a create is writing into right now, which a refresh must not
  /// take for worktrees that have gone.
  var claimedPaths: Set<Worktree.ID> { Set(claims.keys) }
}
