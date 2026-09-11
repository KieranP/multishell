import Foundation
import MultishellCore
import MultishellProcess

/// Whether a worktree's branch has landed: five reads, one per way work
/// lands, none of them writing. See docs/design/merged-branch.md.
extension WorktreeService {
  /// The branches `base` can reach, in one process for the whole repository.
  /// `nil` where git could not answer, which is not "none".
  public func mergedBranches(into base: String, in project: Project) async -> Set<String>? {
    guard
      let output = await git.output(
        ["branch", "--merged", base, "--format=%(refname:short)"], in: project.path)
    else { return nil }
    return MergedBranchParser.parse(output)
  }

  /// Whether `branch` has ever had work of its own. `nil` is a read that
  /// failed, not an empty reflog; see `ReflogWorkParser`.
  public func hasWorkOfItsOwn(_ branch: String, in project: Project) async -> Bool? {
    // `--`, or a branch sharing a name with a path is "both revision and
    // filename" and the read fails rather than answers.
    guard
      let output = await git.output(
        ["log", "-g", "--format=%gs", branch, "--"], in: project.path)
    else { return nil }
    return ReflogWorkParser.parse(output)
  }

  /// Whether `base` has an equivalent patch for every commit on `branch`:
  /// how a rebase-merge lands. `nil` where git could not answer.
  public func isPatchEquivalent(
    _ branch: String, against base: String, in project: Project
  ) async -> Bool? {
    guard let output = await git.output(["cherry", base, branch], in: project.path) else {
      return nil
    }
    return PatchEquivalenceParser.parse(output)
  }

  /// Whether `base` holds any commit `branch` has not, telling an upstream
  /// deleted on a merge from one never there. `-n 1` is the whole answer.
  public func isBehind(_ branch: String, of base: String, in project: Project) async -> Bool? {
    let output = await git.output(
      ["rev-list", "--count", "-n", "1", "\(branch)..\(base)"], in: project.path)
    guard let text = output?.trimmingCharacters(in: .whitespacesAndNewlines), let count = Int(text)
    else { return nil }
    return count > 0
  }

  /// Whether the base reads the same as `branch` wherever it changed
  /// anything: what a squash merge leaves. Errs towards no badge.
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

  /// `--` for the reason `hasWorkOfItsOwn` gives: `git diff <base> <branch>`
  /// reads the second name as a path if the repository holds one.
  private func changedPaths(in revisions: [String], of project: Project) async -> Set<String>? {
    guard
      let output = await git.output(
        ["diff", "--name-only", "-z"] + revisions + ["--"], in: project.path)
    else { return nil }
    return ChangedPathParser.parse(output)
  }
}
