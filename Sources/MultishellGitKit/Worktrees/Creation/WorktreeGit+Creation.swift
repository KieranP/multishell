import Foundation
import MultishellCore
import MultishellProcess

extension WorktreeGit {
  /// `git worktree add [-b <branch>] <path> <start point>`; `createsBranch: false` checks out an
  /// existing branch. No timeout, only `stopper`; see worktrees/creating-and-removing.md.
  func add(
    branch: String,
    at path: URL,
    basedOn startPoint: String?,
    createsBranch: Bool,
    tracksStartPoint: Bool,
    in project: Project,
    stopper: ProcessStopper?,
  ) async throws {
    var arguments = ["worktree", "add"]
    if createsBranch { arguments += ["-b", branch] }
    if createsBranch, !tracksStartPoint { arguments.append("--no-track") }
    // `--` keeps a start point from the command line, such as `--lock`, from being read as a flag.
    arguments += ["--", path.path, createsBranch ? (startPoint ?? "HEAD") : branch]
    _ = try await runner.run(
      arguments,
      in: project.path,
      configuration: await checkoutWorkers(in: project),
      stopper: stopper,
    )
  }

  /// One worker per core, where git's default is one in all, unless the user
  /// chose a count. See Docs/design/worktrees/creating-and-removing.md.
  private func checkoutWorkers(in project: Project) async -> [String: String] {
    let isUserSet = await runner.succeeds(
      ["config", "--get", "checkout.workers"],
      in: project.path,
    )
    return isUserSet ? [:] : ["checkout.workers": "0"]
  }

  /// Written once, a second after the checkout: git trusts no stat data from the
  /// second an index was written in; see Docs/design/worktrees/creating-and-removing.md.
  func settleIndex(of path: URL, stopper: ProcessStopper?) async {
    guard settlesNewIndex else { return }
    let now = Date().timeIntervalSince1970
    let settled = ContinuousClock.now + .seconds(now.rounded(.down) + 1.01 - now)
    // In slices, so the sheet's Cancel ends the wait rather than sitting it out.
    while stopper?.isStopRequested != true, ContinuousClock.now < settled {
      try? await Task.sleep(for: min(.milliseconds(50), settled - .now))
    }
    guard stopper?.isStopRequested != true else { return }
    _ = await runner.output(["update-index", "-q", "--refresh"], in: path)
  }
}
