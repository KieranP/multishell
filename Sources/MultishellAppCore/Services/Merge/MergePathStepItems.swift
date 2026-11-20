import MultishellCore
import MultishellServices

/// What one merge path step lists that Send can carry: the checks step its
/// failing checks, the step holding the threads each thread.
public struct MergePathStepItems: Equatable, Sendable {
  /// The list under a step, which its title collapses.
  public enum CollapsibleList: Equatable, Sendable {
    case checks
    case threads
  }

  /// Each failing check's, a passing one having none.
  public let checkCandidates: [PullRequestCheck: HandoffCandidate]
  public let threads: [PullRequestThread]
  /// Every item's in the order the step lists them, which its own checkbox covers.
  public let candidates: [HandoffCandidate]
  /// `nil` for a step with no list under it.
  public let collapsibleList: CollapsibleList?
  /// By thread id.
  private let threadCandidates: [String: HandoffCandidate]

  /// What the step's own checkbox sends, which its title, a status, does not say.
  public var sendAllLabel: String {
    collapsibleList == .threads ? t("handoff.send-all-threads") : t("handoff.send-all-checks")
  }

  /// Whether every check row keeps the trailing slot, so the Required tags line up.
  public var showsHandoffSlot: Bool { !checkCandidates.isEmpty }

  /// `threads` is the pull request's, listed only where `step` holds them; which
  /// checks are sendable is `PullRequestHandoffItem.items`'s rule, as the foot's.
  init(
    of step: MergePath.Step,
    in path: MergePath,
    headCommit: String,
    threads: [PullRequestThread],
  ) {
    let items = PullRequestHandoffItem.items(
      checks: step.kind == .checks ? path.checks : nil,
      headCommit: headCommit,
      threads: path.threadsStep == step.kind ? threads : [],
    )
    var checkCandidates: [PullRequestCheck: HandoffCandidate] = [:]
    var threadCandidates: [String: HandoffCandidate] = [:]
    var listedThreads: [PullRequestThread] = []
    for item in items {
      switch item {
      case .check(let check, _):
        checkCandidates[check] = item.candidate

      case .thread(let thread):
        threadCandidates[thread.id] = item.candidate
        listedThreads.append(thread)
      }
    }
    self.checkCandidates = checkCandidates
    self.threadCandidates = threadCandidates
    self.threads = listedThreads
    candidates = items.map(\.candidate)
    collapsibleList =
      if step.kind == .checks { .checks } else if !listedThreads.isEmpty { .threads } else { nil }
  }

  public func candidate(of thread: PullRequestThread) -> HandoffCandidate? {
    threadCandidates[thread.id]
  }
}
