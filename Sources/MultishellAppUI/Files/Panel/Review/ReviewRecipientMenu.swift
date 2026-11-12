import MultishellAppCore
import MultishellCore
import SwiftUI

/// Which agent pane a review goes to: each with its mark, its tab and its state.
struct ReviewRecipientMenu: View {
  let recipients: [ReviewRecipient]
  let picked: ReviewRecipient
  let now: Date
  let theme: Theme
  let pick: (TerminalSession.ID) -> Void

  var body: some View {
    Menu {
      ForEach(recipients) { recipient in
        Button {
          pick(recipient.id)
        } label: {
          Label {
            Text(
              t(
                "review.recipient-item",
                recipient.agentName,
                recipient.tabTitle,
                recipient.stateText(at: now),
              )
            )
          } icon: {
            mark(of: recipient)
          }
        }
      }
    } label: {
      // AppKit's own indicator is drawn in the system's colour, so the label draws one.
      HStack(spacing: 4) {
        Label {
          Text(picked.agentName)
        } icon: {
          mark(of: picked)
        }
        Image(systemName: "chevron.down")
          .imageScale(.small)
          .accessibilityHidden(true)
      }
    }
    .menuStyle(.button)
    .menuIndicator(.hidden)
    .buttonStyle(ThemedButtonStyle(fill: theme.filesPanel.fill, text: theme.filesPanel.text))
    .fixedSize()
    .accessibilityLabel(t("review.recipient-menu"))
  }

  private func mark(of recipient: ReviewRecipient) -> Image? {
    AgentMarkImage.image(for: recipient.agentID, tint: theme.agentMarkRGB(recipient.agentID))
  }
}
