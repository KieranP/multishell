import Foundation
import MultishellCore

/// The ref a project's merges are measured against, and where it points now.
/// The tip travels with it because a merge check is memoised on it.
public struct DefaultBranch: Hashable, Sendable {
  /// As git would print it short: `origin/main`, `main`, `upstream/trunk`.
  public let shortName: String
  /// The branch with no remote in front of it, which is what a worktree
  /// sitting on the default branch has as its own branch.
  public let nameWithoutRemote: String
  public let tip: String
  /// What git is handed: a tag named `main` or `origin/main` ties with the
  /// short form and wins it; see Docs/design/merged-branch.md.
  let fullName: String

  /// The refs to try, in order. A remote-tracking ref beats a local branch
  /// of the same name; an override falls back to no default at all.
  static func candidateRefs(override: String?, originHeadTarget: String?) -> [String] {
    var refs: [String] = []
    func add(_ ref: String) {
      if !refs.contains(ref) { refs.append(ref) }
    }
    if let override = override?.trimmedOrNil {
      add(RefName.remote("origin/" + override))
      add(RefName.local(override))
      add(RefName.remote(override))
      return refs
    }
    // What the clone recorded as the remote's own default, the only answer
    // that is not a guess.
    if let originHeadTarget, !originHeadTarget.isEmpty { add(originHeadTarget) }
    add(RefName.remote("origin/main"))
    add(RefName.remote("origin/master"))
    add(RefName.local("main"))
    add(RefName.local("master"))
    return refs
  }

  /// The first candidate `refs` holds, or `nil`. No default branch means no
  /// badge, rather than one measured against a guess.
  static func resolve(from refs: [BranchRef], override: String?) -> Self? {
    let byName = Dictionary(keepingFirst: refs.map { ($0.fullName, $0) })
    let originHeadTarget = byName[RefName.originHead]?.symref
    for candidate in candidateRefs(override: override, originHeadTarget: originHeadTarget) {
      guard let ref = byName[candidate] else { continue }
      return Self(
        shortName: ref.shortName,
        nameWithoutRemote: ref.nameWithoutRemote,
        tip: ref.tip,
        fullName: ref.fullName,
      )
    }
    return nil
  }
}
