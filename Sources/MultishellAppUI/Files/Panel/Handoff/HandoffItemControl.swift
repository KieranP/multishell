import MultishellAppCore
import MultishellCore
import SwiftUI

/// A sendable row's trailing slot: its checkbox, or the sent bubble once sent.
/// A row with nothing to send keeps the slot empty, so its column holds.
struct HandoffItemControl: View {
  let model: AppModel
  /// `nil` for a row that keeps the slot with nothing to send.
  let candidate: HandoffCandidate?
  let worktreeID: Worktree.ID
  /// What VoiceOver names the checkbox for, the row's check, thread, job or output.
  let itemName: String
  let theme: Theme

  var body: some View {
    let metrics = model.metrics
    let state = candidate.map { model.handoffState(of: $0, in: worktreeID) }
    Group {
      switch state {
      case .sent(let agentName):
        HandoffSentBubble(
          agentName: agentName,
          size: metrics.servicePageRowGlyphSize + 2,
          theme: theme,
        ) {
          guard let candidate else { return }
          model.unmarkHandoffItemSent(candidate.id, in: worktreeID)
        }

      case .checked, .unchecked:
        HandoffCheckbox(
          state: state == .checked ? .checked : .unchecked,
          label: t("handoff.send-item", itemName),
        ) {
          guard let candidate else { return }
          model.toggleHandoffItem(candidate, in: worktreeID)
        }

      case nil:
        Color.clear
      }
    }
    .frame(width: metrics.handoffSlotWidth, alignment: .trailing)
  }
}
