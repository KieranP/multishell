import Foundation
import MultishellCore

/// Link clicks being judged. One answered after a later click is dropped, so a
/// share that stopped answering holds nothing back.
@MainActor
final class GhosttyLinkClicks {
  typealias Opening = GhosttyLinkRule.Opening

  /// A test swaps it for one it can hold back, as a share that stopped answering does.
  private let judgeClick: @Sendable (GhosttyClickedLink) -> Opening?
  private var clicksMade = 0
  /// Each link being judged, with its latest click's number and what that click does.
  private var clicksBeingJudged:
    [GhosttyClickedLink: (number: Int, act: @MainActor (Opening?) -> Void)] = [:]

  init(judge: @escaping @Sendable (GhosttyClickedLink) -> Opening? = judgeByTheRule) {
    judgeClick = judge
  }

  nonisolated private static func judgeByTheRule(_ click: GhosttyClickedLink) -> Opening? {
    click.isHyperlink
      ? GhosttyLinkRule.opening(forHyperlink: click.text, in: click.directory)
      : GhosttyLinkRule.opening(for: click.text, in: click.directory)
  }

  /// Judged on Dispatch, its stats able to hang; `act` runs on the main actor
  /// after libghostty's click returns, which holds the pane's renderer lock.
  func judge(_ click: GhosttyClickedLink, then act: @escaping @MainActor (Opening?) -> Void) {
    clicksMade += 1
    // Judged again, a link stuck on a dead share would only park another thread.
    let isBeingJudged = clicksBeingJudged[click] != nil
    clicksBeingJudged[click] = (clicksMade, act)
    guard !isBeingJudged else { return }
    let judgeClick = judgeClick
    Task { [weak self] in
      let opening = await runOnDispatch { judgeClick(click) }
      guard let self, let latest = clicksBeingJudged.removeValue(forKey: click),
        latest.number == clicksMade
      else { return }
      latest.act(opening)
    }
  }
}
