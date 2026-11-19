import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// The PR page's foot, while a check fails or a thread is unresolved. Its own view,
/// so an agent's state or a log read's count redraws it and not the merge path.
struct PullRequestSendFooter: View {
  let model: AppModel
  let worktree: Worktree
  let pullRequest: PullRequest
  let path: MergePath
  let threads: [PullRequestThread]
  let theme: Theme

  var body: some View {
    if let footer = model.pullRequestHandoffFooter(
      of: worktree,
      along: path,
      on: pullRequest,
      threads: threads,
    ) {
      HandoffSendFooter(
        footer: footer,
        note: model.handoffMiss(of: worktree, on: .pullRequest),
        metrics: model.metrics,
        theme: theme,
      ) { sessionID in
        model.pickHandoffRecipient(sessionID, in: worktree.id)
      } send: { sessionID in
        Task {
          await model.sendPullRequestFeedback(of: worktree.id, to: sessionID, takingFocus: true)
        }
      }
    }
  }
}
