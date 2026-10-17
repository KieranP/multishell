import MultishellAppCore
import MultishellCore
import SwiftUI

/// A shell, then every agent found on the PATH. What ⌘T does, which turns
/// on auto-start, is not among them: each item here says what it starts.
struct NewTabMenu: View {
  let model: AppModel
  let groupID: TabGroup.ID
  let isFocusedGroup: Bool
  let theme: Theme

  var body: some View {
    Menu {
      Button {
        model.newShellTab(in: groupID)
      } label: {
        itemLabel(t("menu.new-shell-tab"), agentID: nil)
      }
      ForEach(model.newTabAgentIDs, id: \.self) { id in
        Button {
          model.newAgentTab(id, in: groupID)
        } label: {
          itemLabel(model.newAgentTabMenuLabel(id), agentID: id)
        }
      }
    } label: {
      newTabLabel
    }
    .glyphMenuStyle()
    .frame(width: model.metrics.newTabMenuWidth, height: model.metrics.tabHeight)
    .help(TabStripButtonText.newTabHelp(isFocusedGroup: isFocusedGroup))
    .accessibilityLabel(TabStripButtonText.newTabLabel)
  }

  /// Painted as well as shaped: a menu is hit-tested by what its label draws,
  /// so a clear frame around the glyphs would miss.
  private var newTabLabel: some View {
    HStack(spacing: UIMetrics.menuChevronGap) {
      Image(systemName: "plus")
        .font(model.metrics.font(size: model.metrics.glyph, weight: .medium))
        .accessibilityHidden(true)
      Image(systemName: "chevron.down")
        .font(model.metrics.font(size: model.metrics.menuChevronSize, weight: .bold))
        .accessibilityHidden(true)
    }
    .foregroundStyle(theme.tabBar.textSecondary)
    .padding(.leading, model.metrics.stripGlyphInset)
    .frame(
      width: model.metrics.newTabMenuWidth,
      height: model.metrics.tabHeight,
      alignment: .leading,
    )
    .background(theme.tabBar.background)
    .contentShape(.rect)
  }

  /// The item's mark, rendered: a menu is AppKit's, which draws a title and an
  /// image, and the shell's symbol label showed no icon there.
  @ViewBuilder
  private func itemLabel(_ title: String, agentID: String?) -> some View {
    if let image = AgentMarkImage.image(for: agentID, tint: agentID.flatMap(theme.agentMarkRGB)) {
      Label {
        Text(title)
      } icon: {
        image
      }
    } else {
      Text(title)
    }
  }
}
