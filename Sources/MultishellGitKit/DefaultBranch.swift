import Foundation

/// The ref a project's merges are measured against, and where it points now.
///
/// The tip travels with the ref because a merge check is memoised on it: a
/// refresh that finds the trunk and a branch where it left them asks git
/// nothing further.
public struct DefaultBranch: Hashable, Sendable {
  /// As git would print it short: `origin/main`, `main`, `upstream/trunk`.
  public let ref: String
  /// The branch with no remote in front of it, which is what a worktree
  /// sitting on the trunk has as its own branch.
  public let branch: String
  public let tip: String

  public init(ref: String, branch: String, tip: String) {
    self.ref = ref
    self.branch = branch
    self.tip = tip
  }

  /// The refs to try, in order, for a project.
  ///
  /// A remote-tracking ref is preferred over a local branch of the same
  /// name: a local `main` is stale until someone pulls, and what a branch
  /// has been merged into is a question about the remote. An `override` the
  /// user typed is tried on the remote first, then locally, then as a
  /// remote-qualified name they may have typed in full; nothing falls back
  /// to the defaults after it, since a name that resolves to nothing should
  /// say so rather than quietly measure against something else.
  ///
  /// `originHead` is the full ref `refs/remotes/origin/HEAD` points at.
  public static func candidateRefs(override: String?, originHead: String?) -> [String] {
    var refs: [String] = []
    func add(_ ref: String) {
      if !refs.contains(ref) { refs.append(ref) }
    }
    if let override = override?.trimmingCharacters(in: .whitespaces), !override.isEmpty {
      add(BranchRef.remotePrefix + "origin/" + override)
      add(BranchRef.localPrefix + override)
      add(BranchRef.remotePrefix + override)
      return refs
    }
    // What the clone recorded as the remote's own default, the only answer
    // that is not a guess.
    if let originHead, !originHead.isEmpty { add(originHead) }
    add(BranchRef.remotePrefix + "origin/main")
    add(BranchRef.remotePrefix + "origin/master")
    add(BranchRef.localPrefix + "main")
    add(BranchRef.localPrefix + "master")
    return refs
  }

  /// The first candidate `refs` actually holds, or `nil` for a repository
  /// with none: a fresh `git init` on a branch named something else, or an
  /// override naming a branch that is not there. No default branch means no
  /// badge, rather than a badge measured against a guess.
  public static func resolve(from refs: [BranchRef], override: String?) -> DefaultBranch? {
    let byName = Dictionary(refs.map { ($0.fullName, $0) }, uniquingKeysWith: { first, _ in first })
    let originHead = byName[BranchRef.originHead]?.symref
    for candidate in candidateRefs(override: override, originHead: originHead) {
      guard let ref = byName[candidate] else { continue }
      return DefaultBranch(ref: ref.shortName, branch: ref.branchName, tip: ref.tip)
    }
    return nil
  }
}
