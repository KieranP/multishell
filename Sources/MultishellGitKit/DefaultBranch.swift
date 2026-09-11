import Foundation

/// The ref a project's merges are measured against, and where it points now.
/// The tip travels with it because a merge check is memoised on it.
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

  /// The refs to try, in order. A remote-tracking ref beats a local branch
  /// of the same name; an override falls back to no default at all.
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

  /// The first candidate `refs` holds, or `nil`. No default branch means no
  /// badge, rather than one measured against a guess.
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
