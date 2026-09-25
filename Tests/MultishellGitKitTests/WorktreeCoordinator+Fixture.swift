import Foundation
import MultishellCore
import MultishellProcess

@testable import MultishellGitKit

extension WorktreeCoordinator {
  /// The verdicts alone, which is all a merge test asks about.
  func mergeStates(
    of branches: [String], in project: Project, inputs: MergeInputs
  ) async -> [String: WorktreeMergeState] {
    await readMerges(of: branches, in: project, inputs: inputs).compactMapValues(\.state)
  }

  /// Both halves of a create in `AppModel`'s order, awaited together; the app keeps them apart so
  /// a worktree can be worked in while a slow hook still runs.
  @discardableResult
  func create(
    branch rawBranch: String,
    basedOn startPoint: String? = nil,
    createBranch: Bool = true,
    in project: Project,
    settings: WorktreeSettings,
    shellPath: String? = nil,
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil,
    onStep: (@Sendable (WorktreeCreationStep) -> Void)? = nil
  ) async throws -> URL {
    let path = try await add(
      branch: rawBranch, basedOn: startPoint, createBranch: createBranch, in: project,
      settings: settings, shellPath: shellPath, timeout: timeout, stopper: stopper, onStep: onStep)
    try await runPostCreate(
      for: project, worktreePath: path,
      branch: Self.branchName(rawBranch, createBranch: createBranch, settings: settings),
      shellPath: shellPath, timeout: timeout, stopper: stopper)
    return path
  }

  /// The removal with the directory unlinked in place of a Trash, for tests
  /// about the git side of it.
  func remove(
    _ worktree: Worktree, deletingBranch: Bool = false, in project: Project,
    shellPath: String? = nil, onStep: (@Sendable (WorktreeRemovalStep) -> Void)? = nil
  ) async throws {
    try await remove(
      worktree, deletingBranch: deletingBranch, in: project, shellPath: shellPath,
      trash: { try FileManager.default.removeItem(at: $0) }, onStep: onStep)
  }
}
