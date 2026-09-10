import Foundation
import MultishellCore
import MultishellProcess

/// Whether a worktree's branch has already landed on the branch its
/// project measures merges against. Five reads, each answering for a
/// different way work lands, because no single git question separates a
/// branch that was merged from one that never left; `WorktreeCoordinator`
/// asks them in order and `WorktreeMergeState` records the verdict.
extension WorktreeService {
  /// The branches `base` can reach: merged into it by a merge commit or a
  /// fast-forward. One process answers for every branch in the repository,
  /// which is why the check starts here rather than with a `merge-base` per
  /// worktree.
  /// `nil` where git could not answer, which is not the same as "none":
  /// taken as an answer it would be cached as a confident "not merged"
  /// until the branch next moved.
  public func mergedBranches(into base: String, in project: Project) async -> Set<String>? {
    guard
      let output = await git.output(
        ["branch", "--merged", base, "--format=%(refname:short)"], in: project.path)
    else { return nil }
    return MergedBranchParser.parse(output)
  }

  /// Whether `branch` has ever had work of its own, from what git wrote in
  /// its reflog; see `ReflogWorkParser` for how the messages are read.
  ///
  /// This is what tells a branch that has landed from one that never left.
  /// Both are reachable from the default branch, and no amount of ancestry
  /// separates them: a new worktree's branch is an ancestor of the trunk from
  /// the moment it exists, and a `git pull` that fast-forwards it leaves it
  /// one.
  ///
  /// A branch with no reflog to read has no work to show for itself, which
  /// git answers with no output and a success: a bare repository logs no
  /// branch creation, though it does log a commit, and entries expire
  /// everywhere.
  ///
  /// `nil` is a read that failed, which is not that answer; see
  /// `isPatchEquivalent`.
  public func hasWorkOfItsOwn(_ branch: String, in project: Project) async -> Bool? {
    // `--`, or a branch sharing a name with a path in the repository — a
    // `docs` branch beside a `docs/` directory — is "both revision and
    // filename" and the read fails rather than answers.
    guard
      let output = await git.output(
        ["log", "-g", "--format=%gs", branch, "--"], in: project.path)
    else { return nil }
    return ReflogWorkParser.parse(output)
  }

  /// Whether `base` already has an equivalent patch for every commit on
  /// `branch`: how a rebase-merge or a run of cherry-picks lands, which no
  /// ancestry test can see. Costs a patch id per commit on the branch, so
  /// it is asked only about branches `mergedBranches` did not name.
  /// `nil` where git could not answer: a read that failed is not a verdict,
  /// and one recorded as if it were would be pinned to the tips it was
  /// reached at and never asked about again.
  public func isPatchEquivalent(
    _ branch: String, against base: String, in project: Project
  ) async -> Bool? {
    guard let output = await git.output(["cherry", base, branch], in: project.path) else {
      return nil
    }
    return PatchEquivalenceParser.parse(output)
  }

  /// Whether `base` holds any commit `branch` has not, from
  /// `git rev-list --count -n 1 <branch>..<base>`.
  ///
  /// What tells an upstream deleted on a merge from one that was never
  /// there: work that landed on the base left a commit on it, so a branch
  /// level with the base cannot have been merged into it. Asked only of the
  /// branches whose upstream is gone, which are few.
  ///
  /// `-n 1` because one commit is the whole answer, and a branch cut before
  /// a monorepo's last few thousand would otherwise be counted out in full.
  ///
  /// `nil` where git could not answer; see `isPatchEquivalent`.
  public func isBehind(_ branch: String, of base: String, in project: Project) async -> Bool? {
    let output = await git.output(
      ["rev-list", "--count", "-n", "1", "\(branch)..\(base)"], in: project.path)
    guard let text = output?.trimmingCharacters(in: .whitespacesAndNewlines), let count = Int(text)
    else { return nil }
    return count > 0
  }

  /// Whether the base reads the same as `branch` everywhere the branch has
  /// changed anything: the paths the branch has touched since it forked,
  /// against the paths where the two differ now, with nothing in both.
  ///
  /// What a squash merge leaves that a gone upstream does not say by itself:
  /// the branch's content is on the base. Without it the badge stands on a
  /// worktree holding commits made after the squash landed, which are the
  /// only copy of that work — and `git status` cannot count them, a branch
  /// whose upstream is gone being ahead of nothing there is to be ahead of.
  ///
  /// A path the base has changed since counts as differing, so the answer
  /// errs towards no badge. `nil` where git could not answer.
  public func changesAreOnBase(
    _ branch: String, against base: String, in project: Project
  ) async -> Bool? {
    // `base...branch`, so what the branch changed is measured from where it
    // forked and not from the trunk as it stands now.
    guard let own = await changedPaths(in: ["\(base)...\(branch)"], of: project),
      let differing = await changedPaths(in: [base, branch], of: project)
    else { return nil }
    return own.isDisjoint(with: differing)
  }

  /// `--` for the reason `hasWorkOfItsOwn` gives, and here it is the two-name
  /// form that needs it: `git diff <base> <branch>` reads the second name as
  /// a path if the repository holds one.
  private func changedPaths(in revisions: [String], of project: Project) async -> Set<String>? {
    guard
      let output = await git.output(
        ["diff", "--name-only", "-z"] + revisions + ["--"], in: project.path)
    else { return nil }
    return ChangedPathParser.parse(output)
  }
}
