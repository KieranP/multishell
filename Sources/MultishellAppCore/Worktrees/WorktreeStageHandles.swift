import MultishellCore
import MultishellProcess

/// The handles to what is running while a worktree is built or removed.
/// Never drawn: `WorktreeOperations` beside it is what the pane shows.
struct WorktreeStageHandles: Sendable {
  private var setups: [Worktree.ID: Task<Void, Never>] = [:]
  private var stoppers: [Worktree.ID: ProcessStopper] = [:]
  /// The pre-create hook and `git worktree add` under the sheet, which run
  /// before there is a worktree to key a handle by.
  private var creation: ProcessStopper?

  init() {}

  /// The file lists and post-create hook still running on `id`, as one task,
  /// so a test can await it.
  func setup(of id: Worktree.ID) -> Task<Void, Never>? { setups[id] }

  func stopper(of id: Worktree.ID) -> ProcessStopper? { stoppers[id] }

  /// Behind the pane's Cancel: a hook by signal, a file list between files.
  func stopStage(of id: Worktree.ID) {
    stoppers[id]?.stop()
  }

  /// The handle is installed before the task is made, so a Cancel clicked in
  /// between finds something to stop. Hence two calls and not one.
  mutating func arm(_ stopper: ProcessStopper, on id: Worktree.ID) {
    stoppers[id] = stopper
  }

  mutating func trackSetup(_ setup: Task<Void, Never>, on id: Worktree.ID) {
    setups[id] = setup
  }

  /// The stop handle goes only where it is still `stopper`: a later stage on
  /// the worktree owns its own, and a removal drops no create's setup task.
  mutating func disarm(_ id: Worktree.ID, ifStillHeldBy stopper: ProcessStopper) {
    if stoppers[id] === stopper { stoppers[id] = nil }
  }

  /// A setup stage ended: its task and, if still its own, its stop handle.
  mutating func end(_ id: Worktree.ID, ifStillHeldBy stopper: ProcessStopper) {
    setups[id] = nil
    disarm(id, ifStillHeldBy: stopper)
  }

  /// The sheet's Cancel while the pre-create hook or git runs.
  func cancelCreation() {
    creation?.stop()
  }

  /// Whether `stopper` is the create the sheet is showing. A step reported by
  /// an older one is dropped.
  func isCreating(with stopper: ProcessStopper) -> Bool {
    creation === stopper
  }

  mutating func beginCreation(with stopper: ProcessStopper) {
    creation = stopper
  }

  /// Only the create still showing lets go: two can overlap, and the first
  /// to end would otherwise take the other's Cancel with it.
  mutating func endCreation(with stopper: ProcessStopper) {
    if creation === stopper { creation = nil }
  }
}
