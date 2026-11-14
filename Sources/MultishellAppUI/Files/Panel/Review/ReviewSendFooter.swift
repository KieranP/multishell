import MultishellAppCore
import MultishellCore
import SwiftUI

/// Review's foot: "Send to [agent] Send", what the last Send did, or why there is
/// nobody to send to.
struct ReviewSendFooter: View {
  let model: AppModel
  let worktree: Worktree
  let theme: Theme

  /// The picker's "working for 6m", kept current while Review is shown.
  @State private var now = Date()

  var body: some View {
    let metrics = model.metrics
    Group {
      switch model.reviewFooter(of: worktree) {
      case .sent(let receipt):
        HStack(spacing: 8) {
          Text(receipt.summary)
            .foregroundStyle(theme.filesPanel.textSecondary)
            .lineLimit(1)
          Spacer(minLength: 0)
        }

      case .ready(let picked, let recipients, let canSend):
        // A narrow panel drops "Send to" rather than wrap it a letter a line.
        ViewThatFits(in: .horizontal) {
          readyRow(picked: picked, recipients: recipients, canSend: canSend, labelled: true)
          readyRow(picked: picked, recipients: recipients, canSend: canSend, labelled: false)
        }

      case .noRecipient(let text):
        HStack(spacing: 8) {
          Text(text)
            .foregroundStyle(theme.filesPanel.textSecondary)
          Spacer(minLength: 0)
          Button(t("review.send")) {}
            .buttonStyle(sendButtonStyle)
            .fixedSize()
            .disabled(true)
        }
      }
    }
    .font(metrics.font(size: metrics.secondary))
    .controlSize(.small)
    .padding(.horizontal, UIMetrics.panelSideInset)
    .padding(.vertical, 10)
    .hairline(.top, theme.filesPanel)
    .ticking($now, every: .seconds(60))
  }

  private var sendButtonStyle: ThemedButtonStyle {
    ThemedButtonStyle(
      fill: theme.color(for: .attention, on: theme.filesPanel),
      text: theme.filesPanel.background,
    )
  }

  private func readyRow(
    picked: ReviewRecipient,
    recipients: [ReviewRecipient],
    canSend: Bool,
    labelled: Bool,
  ) -> some View {
    HStack(spacing: 8) {
      if labelled {
        Text(t("review.send-to"))
          .foregroundStyle(theme.filesPanel.textSecondary)
          .fixedSize()
      }
      ReviewRecipientMenu(recipients: recipients, picked: picked, now: now, theme: theme) {
        sessionID in
        model.pickReviewRecipient(sessionID, in: worktree.id)
      }
      Spacer(minLength: 0)
      Button(t("review.send")) {
        model.sendReview(of: worktree.id, to: picked.id, takingFocus: true)
      }
      .buttonStyle(sendButtonStyle)
      .fixedSize()
      .disabled(!canSend)
    }
  }
}
