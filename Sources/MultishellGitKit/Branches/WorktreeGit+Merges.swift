import Foundation
import MultishellCore

/// Whether a worktree's branch has landed: five reads, one per way work
/// lands, none of them writing. See Docs/design/merged-branch.md.
extension WorktreeGit {
  /// The branches `base` can reach; `nil` where git could not answer, which
  /// is not "none". `lstrip=2`, since `:short` answers `heads/x` for a tie.
  func mergedBranches(into base: String, in project: Project) async -> Set<String>? {
    guard
      let output = await runner.output(
        ["branch", "--merged", base, "--format=%(refname:lstrip=2)"], in: project.path)
    else { return nil }
    return MergedBranchParser.parse(output)
  }

  /// Whether `branch` has ever had work of its own. `nil` is a read that
  /// failed, not an empty reflog; see `ReflogWorkParser`.
  func hasWorkOfItsOwn(_ branch: String, in project: Project) async -> Bool? {
    // `%H` beside the subject: a rebase's finish is judged by where the
    // branch came to rest. `--`, or a branch named like a path fails the read.
    guard
      let output = await runner.output(
        ["log", "-g", "--format=%H %gs", BranchRef.localRef(branch), "--"], in: project.path)
    else { return nil }
    return ReflogWorkParser.parse(output)
  }

  /// Whether `base` has an equivalent patch for every commit on `branch`:
  /// how a rebase-merge lands. `nil` where git could not answer.
  func isPatchEquivalent(
    _ branch: String, against base: String, in project: Project
  ) async -> Bool? {
    guard
      let output = await runner.output(
        ["cherry", base, BranchRef.localRef(branch)], in: project.path)
    else { return nil }
    return PatchEquivalenceParser.parse(output)
  }

  /// Whether `base` holds any commit `branch` has not, telling an upstream
  /// deleted on a merge from one never there. `-n 1` is the whole answer.
  func isBehind(_ branch: String, of base: String, in project: Project) async -> Bool? {
    // `--` for the reason `hasWorkOfItsOwn` gives.
    let output = await runner.output(
      ["rev-list", "--count", "-n", "1", "\(BranchRef.localRef(branch))..\(base)", "--"],
      in: project.path)
    guard let text = output?.trimmingCharacters(in: .whitespacesAndNewlines), let count = Int(text)
    else { return nil }
    return count > 0
  }

  /// Whether the base reads the same as `branch` wherever it changed
  /// anything: what a squash merge leaves. Errs towards no badge.
  func changesAreOnBase(
    _ branch: String, against base: String, in project: Project
  ) async -> Bool? {
    // `base...branch`, so what the branch changed is measured from where it
    // forked and not from the trunk as it stands now.
    guard
      let own = await changedPaths(in: ["\(base)...\(BranchRef.localRef(branch))"], of: project),
      let differing = await changedPaths(in: [base, BranchRef.localRef(branch)], of: project)
    else { return nil }
    return own.isDisjoint(with: differing)
  }

  /// `--` for the reason `hasWorkOfItsOwn` gives: `git diff <base> <branch>`
  /// reads the second name as a path if the repository holds one.
  private func changedPaths(in revisions: [String], of project: Project) async -> Set<String>? {
    guard
      let output = await runner.output(
        ["diff", "--name-only", "-z"] + revisions + ["--"], in: project.path)
    else { return nil }
    return ChangedPathParser.parse(output)
  }
}
