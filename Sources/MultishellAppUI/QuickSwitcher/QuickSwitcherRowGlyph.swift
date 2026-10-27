import MultishellAppCore
import MultishellCore
import SwiftUI

/// What a row is, drawn as the sidebar and the tab strip draw the same thing.
struct QuickSwitcherRowGlyph: View {
  let item: QuickSwitcherItem
  let theme: Theme
  let metrics: UIMetrics

  private var palette: AreaPalette { theme.quickSwitcher }

  var body: some View {
    glyph
      .frame(width: metrics.quickSwitcherGlyphColumn)
      .accessibilityHidden(true)
  }

  @ViewBuilder
  private var glyph: some View {
    switch item.kind {
    case .agent(let id):
      pane(agentID: id)

    case .command:
      symbol("command")

    case .file, .fileTab:
      symbol("doc.text")

    case .project(let settings, let isMissing):
      ProjectIconView(
        settings: settings,
        isMissing: isMissing,
        theme: theme,
        palette: palette,
        size: metrics.glyph,
      )

    case .shell:
      pane(agentID: nil)

    case .worktree:
      StateDot(state: item.state.shownState, theme: theme, palette: palette)
    }
  }

  private func pane(agentID: String?) -> some View {
    PaneGlyph(
      agentID: agentID,
      state: item.state,
      ringFill: palette.background,
      plainTint: palette.textSecondary,
      theme: theme,
      palette: palette,
      size: metrics.paneGlyphSize,
    )
  }

  private func symbol(_ name: String) -> some View {
    Image(systemName: name)
      .font(.system(size: metrics.glyph))
      .foregroundStyle(palette.textSecondary)
      .accessibilityHidden(true)
  }
}
