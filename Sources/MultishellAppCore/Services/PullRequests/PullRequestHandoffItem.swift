import Foundation
import MultishellServices

/// What the PR page can send: a failing check, or an unresolved review thread;
/// see Docs/design/services/send-feedback.md.
enum PullRequestHandoffItem: Hashable, Sendable {
  /// With the head its checks were read at, a link outliving a push.
  case check(PullRequestCheck, headCommit: String)
  case thread(PullRequestThread)

  /// A failing required check starts checked, an optional one unchecked; a
  /// thread checked. A rerun, a push or a new comment makes a new item.
  var candidate: HandoffCandidate {
    switch self {
    case .check(let check, let head):
      HandoffCandidate(
        .check(name: check.displayName, link: check.link, headCommit: head),
        startsChecked: check.isRequired,
      )

    case .thread(let thread):
      HandoffCandidate(
        .thread(id: thread.id, newestCommentID: thread.comments.last?.id ?? thread.id)
      )
    }
  }

  /// The failing checks in the host's order, then the threads oldest first.
  static func items(
    checks: [PullRequestCheck]?,
    headCommit: String,
    threads: [PullRequestThread],
  ) -> [Self] {
    (checks ?? []).filter { $0.status == .failed }.map { .check($0, headCommit: headCommit) }
      + threads.map(Self.thread)
  }
}
