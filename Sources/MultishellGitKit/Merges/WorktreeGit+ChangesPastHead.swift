import Foundation
import MultishellCore

extension WorktreeGit {
  /// Whether `tip` has a commit of its own whose change `head` lacks: by patch,
  /// so a rebased head still holds it, and on no branch but its own.
  public func hasChanges(
    on tip: String,
    pastHead head: String,
    ownRemoteBranch: String,
    ownBranch: String,
    in project: Project,
  ) async
    -> Bool?
  {
    // A commit some other branch holds came with a sync, as from the trunk; a
    // sync's merge commit is no change `git cherry` would weigh.
    let otherBranches = [
      "--exclude=\(ownRemoteBranch)", "--remotes", "--exclude=\(ownBranch)", "--branches",
    ]
    guard
      let unpublished = await runner.output(
        ["rev-list", "--no-merges", tip, "--not", head] + otherBranches,
        in: project.path,
      )
    else { return nil }
    let ownCommits = Set(unpublished.split(whereSeparator: \.isNewline).map(String.init))
    // Patching is the dear half, and a branch with no commit of its own needs none.
    guard !ownCommits.isEmpty else { return false }
    guard let unmatched = await runner.output(["cherry", head, tip], in: project.path)
    else { return nil }
    return !PatchEquivalenceParser.unmatchedCommits(unmatched).isDisjoint(with: ownCommits)
  }
}
