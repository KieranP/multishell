import MultishellAppCore
import MultishellCore
import SwiftUI

/// A card's context menu: what acts on the pane, then `WorktreeActions` under
/// a heading naming the worktree. Both halves carry a Clear Status.
struct AgentCardActions: View {
  let model: AppModel
  let card: AgentBoardCard

  var body: some View {
    Button(t("card.go-to-terminal")) { model.open(card) }
    if card.state != nil {
      Button(t("actions.clear-status")) { model.clearState(ofSession: card.id) }
    }
    if let worktree = model.workspace.worktree(card.worktreeID) {
      Section(model.displayName(of: worktree)) {
        WorktreeActions(model: model, worktree: worktree)
      }
    }
  }
}
