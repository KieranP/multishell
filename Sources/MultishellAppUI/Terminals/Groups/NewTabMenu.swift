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
          itemLabel(model.newAgentTabTitle(id), agentID: id)
        }
      }
    } label: {
      newTabLabel
    }
    .glyphMenuStyle()
    .frame(width: model.metrics.newTabMenuWidth, height: model.metrics.tabHeight)
    // Every item opens in this group. Only the focused one need not say so,
    // being where the keyboard already is.
    .help(isFocusedGroup ? t("tab.new") : t("tab.new-in-group"))
    .accessibilityLabel(t("tab.new"))
  }

  /// Painted as well as shaped: a menu is hit-tested by what its label draws,
  /// so a clear frame around the glyphs would miss.
  private var newTabLabel: some View {
    HStack(spacing: model.metrics.menuChevronGap) {
      Image(systemName: "plus")
        .font(.system(size: model.metrics.icon, weight: .medium))
      Image(systemName: "chevron.down")
        .font(.system(size: model.metrics.menuChevron, weight: .bold))
    }
    .foregroundStyle(theme.textSecondary)
    .padding(.leading, model.metrics.stripGlyphInset)
    .frame(
      width: model.metrics.newTabMenuWidth, height: model.metrics.tabHeight, alignment: .leading
    )
    .background(theme.chromeColor)
    .contentShape(.rect)
  }

  /// The item's mark, rendered: a menu is AppKit's, which draws a title and an
  /// image, and the shell's symbol label showed no icon there.
  @ViewBuilder
  private func itemLabel(_ title: String, agentID: String?) -> some View {
    if let image = AgentMarkImage.image(for: agentID) {
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
