import Foundation
import MultishellCore

extension WorktreeGit {
  /// The retry leaves out every atom a git could refuse as unknown, and
  /// `BranchRefParser` reads a column that is not there as absent.
  private static func refQuery(withOptionalAtoms: Bool) -> [String] {
    var format = [
      "%(refname)", "%(objectname)", "%(upstream)", "%(upstream:track)", "%(symref)",
    ]
    if withOptionalAtoms {
      format += [
        "%(committerdate:unix)", "%(upstream:remotename)", "%(upstream:remoteref)",
        "%(push:remotename)",
      ]
    }
    return [
      "for-each-ref", "--format=" + format.joined(separator: "%09"), "refs/heads", "refs/remotes",
    ]
  }

  /// Every branch with its tip, upstream and date, in one process, the date
  /// and upstream names retried without. `nil` is a failed read, not no branches.
  func branchRefs(_ project: Project) async -> BranchRefList? {
    if let output = await runner.output(Self.refQuery(withOptionalAtoms: true), in: project.path) {
      return BranchRefList(refs: BranchRefParser.parse(output), namesUpstreams: true)
    }
    guard
      let output = await runner.output(Self.refQuery(withOptionalAtoms: false), in: project.path)
    else { return nil }
    return BranchRefList(refs: BranchRefParser.parse(output), namesUpstreams: false)
  }

  /// The names a new worktree can start from, symbolic refs such as
  /// `origin/HEAD` dropped. `nil` is a failed read.
  public func branchNames(_ project: Project) async -> (local: [String], remote: [String])? {
    guard let refs = await branchRefs(project)?.refs.filter({ $0.symref == nil }) else {
      return nil
    }
    return (refs.filter(\.isLocal).map(\.shortName), refs.filter(\.isRemote).map(\.shortName))
  }

  public func currentBranch(_ project: Project) async throws -> String {
    try await runner.run(["rev-parse", "--abbrev-ref", "HEAD"], in: project.path)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Only `--verify --quiet`'s exit 1 says missing: a git that failed any other
  /// way says nothing, and the caller would `branch -D` on the answer.
  func lacksBranch(_ branch: String, in project: Project) async -> Bool {
    await runner.exitStatus(
      ["rev-parse", "--verify", "--quiet", RefName.local(branch)],
      in: project.path,
    ) == 1
  }

  /// What the branch was made from, `origin/release`, as its first reflog entry
  /// says; `nil` where git keeps no reflog for it, and a throw where git failed.
  public func startPoint(ofBranch branch: String, in project: Project) async throws -> String? {
    let prefix = "branch: Created from "
    let output = try await runner.run(
      ["reflog", "show", "--format=%gs", RefName.local(branch)],
      in: project.path,
    )
    guard let first = output.split(whereSeparator: \.isNewline).last, first.hasPrefix(prefix)
    else { return nil }
    return String(first.dropFirst(prefix.count))
  }

  /// The commits the local branch has past `tip`, a remote branch's: those a
  /// push would send. `nil` where git failed.
  public func commitCount(
    ofBranch branch: String,
    past tip: String,
    in directory: URL,
  ) async -> Int? {
    await runner.output(
      ["rev-list", "--count", "\(tip)..\(RefName.local(branch))", "--"],
      in: directory,
    )
    .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
  }

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

  /// `nil` where the branch is gone or git failed.
  func tip(ofBranch branch: String, in project: Project) async -> String? {
    await runner.output(
      ["rev-parse", "--verify", "--quiet", RefName.local(branch)],
      in: project.path,
    )?
    .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// `-D`, a branch cut from another start point being unmerged into HEAD.
  /// Kept where a worktree still lists it, as a SIGKILL can leave the record.
  func deleteBranchIfUnlisted(_ branch: String, in project: Project) async {
    guard let listed = try? await list(project), !listed.contains(where: { $0.branch == branch })
    else { return }
    try? await deleteBranch(branch, in: project, force: true)
  }

  /// `git branch -d`, which refuses a branch with commits no other branch
  /// has; `force` is `-D`.
  func deleteBranch(_ branch: String, in project: Project, force: Bool) async throws {
    _ = try await runner.run(["branch", force ? "-D" : "-d", branch], in: project.path)
  }
}
