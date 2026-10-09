import MultishellAppCore
import MultishellCore
import SwiftUI

/// What a tab in the strip shows and what a click on each part does; `DraggableTab`
/// wraps it in both ends of a drag.
struct TabFace: View {
  let model: AppModel
  let group: TabGroup
  let tab: TerminalTab
  let isFocusedGroup: Bool
  let theme: Theme

  private var isShown: Bool { tab.id == group.shownTabID }
  private var isRenaming: Bool { model.renamingTabID == tab.id }

  var body: some View {
    let isActive = isShown && isFocusedGroup
    let textColor = isActive ? theme.textPrimary : theme.textSecondary
    let state = model.state(of: tab)
    let agentID = model.agentIDAtThePrompt(of: tab)
    let title = model.title(of: tab)
    return HStack(spacing: UIMetrics.tabItemGap) {
      leadingGlyph(state, agentID: agentID, textColor: textColor)

      if isRenaming {
        titleField(initial: title)
      } else {
        Text(title)
          .font(.system(size: model.metrics.secondary, weight: isShown ? .medium : .regular))
          .foregroundStyle(textColor)
          .lineLimit(1)
          .truncationMode(.tail)
      }

      Spacer(minLength: 0)

      if isActive, !isRenaming { closeButton }
    }
    .padding(.horizontal, UIMetrics.tabSideInset)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(isShown ? theme.backgroundColor : .clear)
    .overlay(alignment: .trailing) {
      if !isShown { theme.hairline.frame(width: UIMetrics.hairlineThickness).padding(.vertical, 8) }
    }
    .contentShape(.rect)
    // Simultaneous, not sequential: a plain double-tap makes SwiftUI hold
    // the single tap, and switching should not lag by that timeout.
    .onTapGesture { model.activate(tab) }
    .simultaneousGesture(TapGesture(count: 2).onEnded { beginRenaming() })
    // Every tab strip closes on a middle click, the active one or not.
    .onMiddleClick { model.closeTab(tab.id) }
    // The buttons inside keep their own labels. `.contain`, not `.combine`,
    // which would read the close button's into the tab's.
    .accessibilityElement(children: .contain)
    .accessibilityLabel(
      AccessibilityText.tab(
        title: title, isShown: isShown, isSplit: tab.isSplit, state: state,
        agentName: agentID.map(model.agentDisplayName))
    )
    .selectableButtonTraits(isSelected: isShown)
    .accessibilityAction(named: t("action.rename-spoken")) { beginRenaming() }
    .contextMenu {
      TabActions(model: model, tab: tab)
    }
  }

  /// What the tab is running. A button while there is a state, so a click
  /// clears a stale Working one without activating the tab.
  @ViewBuilder
  private func leadingGlyph(
    _ state: SessionState?, agentID: String?, textColor: Color
  ) -> some View {
    let glyph = PaneGlyph(
      agentID: agentID,
      unmarkedSymbol: tab.isSplit ? PaneSymbol.split : PaneSymbol.terminal,
      state: state,
      ringFill: isShown ? theme.backgroundColor : theme.chromeColor,
      plainTint: textColor,
      theme: theme,
      size: model.metrics.paneGlyphSize)
    if let state {
      Button {
        model.clearState(of: tab)
      } label: {
        // The target the dot had before the mark took the slot, without the
        // width: `tabMinWidth` has none to give. See Docs/design/agents.md.
        glyph.padding(2).contentShape(.rect).padding(-2)
      }
      .buttonStyle(.plain)
      .help(t("tab.state-click-to-clear", state.displayName))
      .accessibilityLabel(t("tab.state-clear-status", state.displayName))
    } else {
      glyph
    }
  }

  /// Names its own tab, like the middle click. `closeActiveTab` is for the
  /// keystroke, which has to ask which window is key first.
  private var closeButton: some View {
    PlainGlyphButton(help: t("tab.close")) {
      model.closeTab(tab.id)
    } glyph: {
      Image(systemName: "xmark")
        .font(.system(size: model.metrics.small, weight: .semibold))
        .frame(width: model.metrics.tabCloseButtonSide, height: model.metrics.tabCloseButtonSide)
    }
    .foregroundStyle(theme.textSecondary)
  }

  /// An empty name clears the custom title rather than storing a blank one;
  /// `InlineNameField` has the keyboard contract.
  private func titleField(initial: String) -> some View {
    InlineNameField(
      initial: initial,
      prompt: t("tab.name-prompt"),
      font: .system(size: model.metrics.secondary, weight: .medium),
      color: theme.textPrimary,
      commit: { model.commitTabRename(of: tab.id, to: $0) },
      cancel: { model.cancelRenamingTab() })
  }

  private func beginRenaming() {
    model.beginRenamingTab(tab.id)
  }
}
