import Foundation
import MultishellCore

/// What one `for-each-ref` answers: each branch's last commit date and tip, and
/// where a default branch resolved, the merge inputs. Dates and tips come back either way.
public struct BranchScan: Hashable, Sendable {
  /// The last commit on each local branch, by the name a worktree has as
  /// its own branch. A branch whose ref carried no date is absent.
  public let lastCommitDates: [String: Date]
  /// Each local branch's tip, by the same name, whether or not a trunk resolved.
  public let branchTips: [String: String]
  /// `nil` for a repository with no branch to measure merges against; see
  /// `DefaultBranch.resolve`.
  public let mergeInputs: MergeInputs?
  /// Where each local branch is published, by its worktree's name for it; `nil`
  /// where the retried read did not ask, so none is known gone.
  public let upstreams: [String: BranchUpstream]?

  /// The override is the project's `defaultBranch` setting, `nil` to detect.
  init(_ list: BranchRefList, defaultBranchOverride override: String?) {
    let refs = list.refs
    let branches = BranchRef.localBranchesByName(refs)
    lastCommitDates = branches.compactMapValues(\.committedAt)
    branchTips = branches.mapValues(\.tip)
    let tips = Dictionary(keepingFirst: refs.map { ($0.fullName, $0.tip) })
    upstreams =
      !list.namesUpstreams
      ? nil
      : branches.compactMapValues { Self.publishedBranch(of: $0, tips: tips) }
    mergeInputs = DefaultBranch.resolve(from: refs, override: override)
      .map { MergeInputs(defaultBranch: $0, branches: branches) }
  }

  /// Where the branch's pull request and runs are filed: under its own name on
  /// the remote its pushes go to, else what it follows; see services.md.
  private static func publishedBranch(
    of ref: BranchRef,
    tips: [String: String],
  ) -> BranchUpstream? {
    let name = ref.shortName
    // `.` is the repository itself: a branch tracking a local one is unpushed.
    let followed = ref.upstreamRemote.flatMap { $0 == "." ? nil : $0 }
    // git pushes to `origin` where nothing names a remote.
    let pushedTo = ref.pushRemote.flatMap { $0 == "." ? nil : $0 } ?? followed ?? "origin"
    let ownName = RefName.remote("\(pushedTo)/\(name)")
    if pushedTo != followed || ref.upstreamBranch != name, let tip = tips[ownName] {
      return BranchUpstream(remote: pushedTo, branch: name, tip: tip)
    }
    // Its own name followed elsewhere was pushed there; another name, pushed
    // to another remote, is someone else's branch it was cut from.
    guard pushedTo == followed || ref.upstreamBranch == name, let followed,
      let branch = ref.upstreamBranch
    else { return nil }
    return BranchUpstream(
      remote: followed,
      branch: branch,
      tip: ref.upstreamRef.flatMap { tips[$0] },
    )
  }
}
