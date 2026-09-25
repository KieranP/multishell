import MultishellCore
import SwiftUI

/// What a pane is running, with its state badged on the mark's corner; drawn
/// by the strip, the sidebar's pane rows and a card. See Docs/design/agents.md.
struct PaneGlyph: View {
  let agentID: String?
  var shellSymbol = AgentMarkView.terminalSymbol
  /// `nil` draws no badge, which is a tab with nothing to report.
  let state: SessionState?
  /// What the badge's ring is filled with, so it reads as a gap in the row
  /// rather than a second ring of colour.
  let ringFill: Color
  let plainTint: Color
  let theme: Theme
  let size: Double

  /// The seven points the tab's dot had before it moved onto the mark; what
  /// it covers is the trade, see Docs/design/agents.md.
  private var dotSize: Double { max(7, (size * 0.6).rounded()) }

  var body: some View {
    AgentMarkView(
      agentID: agentID, shellSymbol: shellSymbol, plainTint: plainTint, size: size
    )
    .overlay(alignment: .bottomTrailing) {
      if let state {
        Circle()
          .fill(theme.color(for: state))
          .frame(width: dotSize, height: dotSize)
          .padding(1.2)
          .background(ringFill, in: Circle())
          // Pushed out to the corner, so what it covers is the mark's edge
          // rather than the middle that carries the shape.
          .offset(x: size * 0.26, y: size * 0.2)
      }
    }
  }
}
