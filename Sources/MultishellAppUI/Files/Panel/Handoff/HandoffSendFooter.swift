import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// A page's foot: "Send to [agent] Send", what the last Send did, or why there is
/// nobody to send to. Review, the PR page and the CI page each feed it.
struct HandoffSendFooter: View {
  let footer: HandoffFooter
  /// Why the last Send sent nothing, said over the row until the next.
  var note: String?
  let metrics: UIMetrics
  let theme: Theme
  let pick: (TerminalSession.ID) -> Void
  let send: (TerminalSession.ID) -> Void

  /// The picker's "working for 6m", kept current while the page is shown.
  @State private var now = Date()

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let note {
        Text(note)
          .foregroundStyle(theme.color(for: .attention, on: theme.filesPanel))
          .fixedSize(horizontal: false, vertical: true)
      }
      row
    }
    .font(metrics.font(size: metrics.secondary))
    .controlSize(.small)
    .padding(.horizontal, UIMetrics.panelSideInset)
    .padding(.vertical, 10)
    .hairline(.top, theme.filesPanel)
    .ticking($now, every: .seconds(60))
  }

  @ViewBuilder private var row: some View {
    Group {
      switch footer {
      case .reading(let text):
        HStack(spacing: 8) {
          CIRunGlyph(
            status: .running,
            theme: theme,
            palette: theme.filesPanel,
            size: metrics.servicePageRowGlyphSize,
          )
          Text(text)
            .foregroundStyle(theme.filesPanel.textSecondary)
            .lineLimit(1)
          Spacer(minLength: 0)
          disabledSendButton
        }

      case .sent(let summary):
        HStack(spacing: 8) {
          Text(summary)
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
          disabledSendButton
        }
      }
    }
  }

  private var disabledSendButton: some View {
    Button(t("handoff.send")) {}
      .buttonStyle(sendButtonStyle)
      .fixedSize()
      .disabled(true)
  }

  private var sendButtonStyle: ThemedButtonStyle {
    ThemedButtonStyle(
      fill: theme.color(for: .attention, on: theme.filesPanel),
      text: theme.filesPanel.background,
    )
  }

  private func readyRow(
    picked: HandoffRecipient,
    recipients: [HandoffRecipient],
    canSend: Bool,
    labelled: Bool,
  ) -> some View {
    HStack(spacing: 8) {
      if labelled {
        Text(t("handoff.send-to"))
          .foregroundStyle(theme.filesPanel.textSecondary)
          .fixedSize()
      }
      HandoffRecipientMenu(
        recipients: recipients,
        picked: picked,
        now: now,
        theme: theme,
        pick: pick,
      )
      Spacer(minLength: 0)
      Button(t("handoff.send")) { send(picked.id) }
        .buttonStyle(sendButtonStyle)
        .fixedSize()
        .disabled(!canSend)
    }
  }
}
