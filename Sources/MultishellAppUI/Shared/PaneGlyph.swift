import MultishellCore
import SwiftUI

/// What a pane is running, with its state badged on the mark's corner: a tab's
/// and a switcher row's. A card's is unbadged; see Docs/design/agents/board-and-pane-rows.md.
struct PaneGlyph: View {
  let agentID: String?
  var unmarkedSymbol = PaneSymbol.terminal
  /// `nil` draws no badge, which is a tab with nothing to report.
  let state: SessionState?
  /// What the badge's ring is filled with, so it reads as a gap in the row
  /// rather than a second ring of colour.
  let ringFill: Color
  /// A wash over `ringFill`, as on a hovered tab; `nil` for none.
  var ringWash: Color?
  let plainTint: Color
  let theme: Theme
  let palette: AreaPalette
  let size: Double

  /// The state dot on the mark's corner; what it covers is the trade, see
  /// Docs/design/agents/board-and-pane-rows.md.
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
      badgeScale: theme.stateDotScale,
      ringFill: ringFill,
      ringWash: ringWash,
      state.map { StateDot(state: $0, theme: theme, palette: palette, diameter: dotSize) },
    )
  }
}
