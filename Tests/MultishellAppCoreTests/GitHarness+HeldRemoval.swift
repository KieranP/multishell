import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

extension GitHarness {
  /// A new worktree on `leaving` whose removal has started and reached `stage`,
  /// where a hook in `settings` holds it.
  func removalHeld(
    in stage: WorktreeOperation.Stage,
    by settings: ProjectSettings,
  ) async throws -> (leaving: Worktree, removal: Task<PresentedRemovalFailure?, Never>) {
    model.setSettings(settings, for: project)
    let leaving = try await createWorktree(onBranch: "leaving")
    let removal = Task {
      await model.removeWorktree(leaving, deletesBranch: false, trashes: false)
    }
    try await waitUntil({ model.worktreeOperations[leaving.id]?.stage == stage }, seconds: 10)
    try #require(model.worktreeOperations[leaving.id]?.stage == stage)
    return (leaving, removal)
  }
}
