import MultishellCore
import SwiftUI

/// What a pane is running, with its state badged on the mark's corner; drawn
/// by the strip, the sidebar's pane rows and a card. See Docs/design/agents.md.
struct PaneGlyph: View {
  let agentID: String?
  var unmarkedSymbol = PaneSymbol.terminal
  /// `nil` draws no badge, which is a tab with nothing to report.
  let state: SessionState?
  /// What the badge's ring is filled with, so it reads as a gap in the row
  /// rather than a second ring of colour.
  let ringFill: Color
  let plainTint: Color
  let theme: Theme
  let palette: AreaPalette
  let size: Double

  /// The state dot on the mark's corner; what it covers is the trade, see
  /// Docs/design/agents.md.
  private var dotSize: Double { UIMetrics.cornerBadgeSize(onGlyphOf: size) }

  var body: some View {
    AgentMarkView(
      agentID: agentID,
      unmarkedSymbol: unmarkedSymbol,
      markTint: agentID.flatMap(theme.agentMarkRGB),
      plainTint: plainTint,
      size: size,
    )
    .cornerBadge(
      onGlyphOf: size,
      ringFill: ringFill,
      state.map { StateDot(state: $0, theme: theme, palette: palette, diameter: dotSize) },
    )
  }
}
