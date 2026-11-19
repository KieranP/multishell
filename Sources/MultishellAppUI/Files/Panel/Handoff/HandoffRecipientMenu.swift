import MultishellAppCore
import MultishellCore
import SwiftUI

/// Which agent pane a Send goes to: each with its mark, its tab and its state.
struct HandoffRecipientMenu: View {
  let recipients: [HandoffRecipient]
  let picked: HandoffRecipient
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
                "handoff.recipient-item",
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
          Text(picked.agentName).lineLimit(1)
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
    .fixedSize(horizontal: false, vertical: true)
    .accessibilityLabel(t("handoff.recipient-menu"))
  }

  private func mark(of recipient: HandoffRecipient) -> Image? {
    AgentMarkImage.image(for: recipient.agentID, tint: theme.agentMarkRGB(recipient.agentID))
  }
}
