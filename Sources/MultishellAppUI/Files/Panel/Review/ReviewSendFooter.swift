import MultishellAppCore
import MultishellCore
import SwiftUI

/// Review's foot, its own view so an agent's state change redraws it and not the
/// page's comment rows.
struct ReviewSendFooter: View {
  let model: AppModel
  let worktree: Worktree
  let theme: Theme

  var body: some View {
    HandoffSendFooter(
      footer: model.reviewFooter(of: worktree),
      metrics: model.metrics,
      theme: theme,
    ) { sessionID in
      model.pickHandoffRecipient(sessionID, in: worktree.id)
    } send: { sessionID in
      model.sendReview(of: worktree.id, to: sessionID, takingFocus: true)
    }
  }
}
