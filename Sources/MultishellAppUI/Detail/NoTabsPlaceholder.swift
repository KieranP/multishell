import MultishellAppCore
import MultishellCore
import SwiftUI

/// A worktree with no tab: a button for a shell and one for each agent the
/// strip's New Tab menu offers. See Docs/design/tabs-and-groups/tab-strip.md.
struct NoTabsPlaceholder: View {
  /// About three buttons a line, a little wider than the caption above.
  private static var buttonsMaxWidth: Double { 520 }

  let model: AppModel
  let worktree: Worktree
  let theme: Theme

  var body: some View {
    DetailPlaceholder(
      title: t("empty.no-terminals", model.displayName(of: worktree)),
      caption: model.offersAgentTabs
        ? t("empty.no-terminals-detail") : t("empty.no-terminals-shell-detail"),
      theme: theme,
      metrics: model.metrics,
    ) {
      PlaceholderSymbol(symbol: PaneSymbol.terminal, theme: theme)
    } footer: {
      // Wrapped short of the area's width: every agent installed made one long row.
      CenteredFlowLayout(spacing: 8) { buttons }
        .frame(maxWidth: Self.buttonsMaxWidth)
        .padding(.top, UIMetrics.placeholderFooterGap)
    }
  }

  @ViewBuilder
  private var buttons: some View {
    PlaceholderButton(title: t("menu.new-shell-tab"), theme: theme, metrics: model.metrics) {
      model.newShellTab()
    } icon: { tint, size in
      mark(nil, tint: tint, size: size)
    }
    ForEach(model.newTabAgentIDs, id: \.self) { id in
      PlaceholderButton(
        title: model.newAgentTabMenuLabel(id),
        theme: theme,
        metrics: model.metrics,
      ) {
        model.newAgentTab(id)
      } icon: { tint, size in
        mark(id, tint: tint, size: size)
      }
    }
  }

  private func mark(_ agentID: String?, tint: Color, size: Double) -> some View {
    AgentMarkView(
      agentID: agentID,
      markTint: agentID.flatMap(theme.agentMarkRGB),
      plainTint: tint,
      size: size,
    )
  }
}
