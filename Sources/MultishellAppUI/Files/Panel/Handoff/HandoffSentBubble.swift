import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// A sent item's mark: a paper plane on a green disc. A click turns it back
/// into a checked box, to send the item again.
struct HandoffSentBubble: View {
  let agentName: String
  let size: Double
  let theme: Theme
  let checkAgain: () -> Void

  var body: some View {
    Button(action: checkAgain) {
      ZStack {
        Circle().fill(theme.color(for: CIRunStatus.passed, on: theme.filesPanel))
        PaperPlaneShape()
          .stroke(
            theme.filesPanel.background,
            style: StrokeStyle(lineWidth: size / 12, lineCap: .round, lineJoin: .round),
          )
          .padding(size * 0.22)
      }
      .frame(width: size, height: size)
      .contentShape(.circle)
    }
    .buttonStyle(.plain)
    .help(t("handoff.sent-to", agentName))
    .accessibilityLabel(t("handoff.sent-to", agentName))
    .accessibilityHint(t("handoff.send-again-hint"))
  }
}
