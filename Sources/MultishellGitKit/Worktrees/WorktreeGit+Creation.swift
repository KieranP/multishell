import Foundation
import MultishellCore
import MultishellProcess

extension WorktreeGit {
  /// `git worktree add [-b <branch>] <path> <start point>`; `createBranch: false`
  /// checks out an existing branch. No timeout, only `stopper`; see worktrees.md.
  func add(
    branch: String,
    at path: URL,
    basedOn startPoint: String? = nil,
    createBranch: Bool = true,
    in project: Project,
    stopper: ProcessStopper? = nil
  ) async throws {
    var arguments = ["worktree", "add"]
    if createBranch { arguments += ["-b", branch] }
    arguments.append(path.path)
    arguments.append(createBranch ? (startPoint ?? "HEAD") : branch)
    _ = try await runner.run(arguments, in: project.path, stopper: stopper)
  }

  /// Written once, a second after the checkout: git trusts no stat data from the
  /// second an index was written in; see Docs/design/worktrees.md.
  func settleIndex(of worktree: URL, stopper: ProcessStopper? = nil) async {
    guard settlesNewIndex else { return }
    let now = Date().timeIntervalSince1970
    let settled = ContinuousClock.now + .seconds(now.rounded(.down) + 1.01 - now)
    // In slices, so the sheet's Cancel ends the wait rather than sitting it out.
    while stopper?.isStopped != true, ContinuousClock.now < settled {
      try? await Task.sleep(for: min(.milliseconds(50), settled - .now))
    }
    guard stopper?.isStopped != true else { return }
    _ = await runner.output(["update-index", "-q", "--refresh"], in: worktree)
  }
}
