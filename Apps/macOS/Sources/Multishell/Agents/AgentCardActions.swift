import MultishellAppCore
import MultishellCore
import SwiftUI

/// A card's context menu: what acts on the pane, then everything that acts
/// on the worktree it is in.
///
/// The worktree half is `WorktreeActions`, the same items the sidebar row
/// and the detail header show, under a heading that names the worktree. The
/// heading is not decoration: both halves carry a Clear Status, and without
/// it there would be no telling which one clears the card in front of you.
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
