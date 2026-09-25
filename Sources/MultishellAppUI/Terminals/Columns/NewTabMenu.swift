import MultishellAppCore
import MultishellCore
import SwiftUI

/// A shell, then every agent found on the PATH. What ⌘T does, which turns
/// on auto-start, is not among them: each item here says what it starts.
struct NewTabMenu: View {
  let model: AppModel
  /// The column every item opens in.
  let groupID: TabGroup.ID
  let isFocused: Bool
  let theme: Theme

  var body: some View {
    Menu {
      Button {
        model.newShellTab(in: groupID)
      } label: {
        Label(t("menu.new-shell-tab"), systemImage: "apple.terminal")
      }
      ForEach(model.installedAgentIDs, id: \.self) { id in
        Button {
          model.newAgentTab(id, in: groupID)
        } label: {
          itemLabel(id)
        }
      }
    } label: {
      newTabLabel
    }
    // Not `.borderlessButton`: that one is an AppKit button, which keeps one
    // image of the label and drops the chevron. See Docs/design/tabs-and-columns.md.
    .menuStyle(.button)
    .buttonStyle(.plain)
    .menuIndicator(.hidden)
    .frame(width: model.metrics.newTabMenuWidth, height: model.metrics.tabHeight)
    // Every item opens in this column. Only the focused one need not say so,
    // being where the keyboard already is.
    .help(isFocused ? t("tab.new") : t("tab.new-in-group"))
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

  /// The agent's mark beside its item. A menu is AppKit's, which draws a
  /// title and an image, so the mark is rendered rather than laid out.
  @ViewBuilder
  private func itemLabel(_ id: String) -> some View {
    if let image = AgentMarkImage.image(for: id) {
      Label {
        Text(itemTitle(id))
      } icon: {
        image
      }
    } else {
      Text(itemTitle(id))
    }
  }

  /// "New Claude Code Tab", and the typed command by its own name rather
  /// than as "New Custom command Tab".
  private func itemTitle(_ id: String) -> String {
    id == AgentCatalogue.customID
      ? t("tab.new-custom-agent") : t("tab.new-named-agent", model.agentDisplayName(id))
  }
}
