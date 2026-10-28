import Foundation
import MultishellCore
import MultishellServices

/// What the services say about one worktree's branch, as its row, its popover
/// and the panel's pages draw it. Runtime only; see Docs/design/services.md.
public struct WorktreeServices: Equatable, Sendable {
  static let empty = Self()

  /// The branch's pull request: an open one over the rest, then the newest.
  /// A merged one is proof the branch landed only while its head is the tip.
  var pullRequest: PullRequest?
  /// A merged pull request the branch has changes of its own past: said, but
  /// no longer standing for the branch having landed.
  var outgrownPullRequest: PullRequest?
  var pullRequestIntegration: ServiceIntegration?
  public internal(set) var ciRun: CIRun?
  var ciIntegration: ServiceIntegration?
  /// The local branch's tip, which a run of another commit is told against.
  public internal(set) var localTip: String?
  /// The latest read that gave no answer, the shown one being older.
  var readProblem: ServiceReadProblem?
  /// What git is asked of a merged pull request whose head is not the tip.
  var changesPastMergedHead: ChangesPastHead?

  public var showsAnything: Bool { shownPullRequest != nil || ciRun != nil }

  /// What the row and the page draw: its own, else a merged one it went
  /// past, whose tooltip says so and beside which a new one is offered.
  public var shownPullRequest: PullRequest? { pullRequest ?? outgrownPullRequest }
}
