import MultishellAppCore
import MultishellCore
import SwiftUI

/// The CI page's foot, while the newest run has failures. Its own view, so an
/// agent's state change redraws it and not the run's workflows.
struct CISendFooter: View {
  let model: AppModel
  let worktree: Worktree
  let listing: CIWorkflowListing
  let theme: Theme

  var body: some View {
    if let footer = model.ciHandoffFooter(of: worktree, over: listing) {
      HandoffSendFooter(
        footer: footer,
        note: model.handoffMiss(of: worktree, on: .ciRuns),
        metrics: model.metrics,
        theme: theme,
      ) { sessionID in
        model.pickHandoffRecipient(sessionID, in: worktree.id)
      } send: { sessionID in
        model.sendCIFailures(of: worktree.id, to: sessionID, takingFocus: true)
      }
    }
  }
}
