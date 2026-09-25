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
  let canLeaveGroup: Bool
  let theme: Theme

  private var isActive: Bool { tab.id == group.activeTabID }
  private var isRenaming: Bool { model.renamingTabID == tab.id }

  var body: some View {
    let isFront = isActive && isFocusedGroup
    let text = isFront ? theme.textPrimary : theme.textSecondary
    let state = model.state(of: tab)
    let agentID = model.agentAtThePrompt(of: tab)
    return HStack(spacing: 7) {
      leadingGlyph(state, agentID: agentID, text: text)

      if isRenaming {
        titleField
      } else {
        Text(model.title(of: tab))
          .font(.system(size: model.metrics.secondary, weight: isActive ? .medium : .regular))
          .foregroundStyle(text)
          .lineLimit(1)
          .truncationMode(.tail)
      }

      Spacer(minLength: 0)

      if isFront, !isRenaming { closeButton }
    }
    .padding(.horizontal, 10)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(isActive ? theme.backgroundColor : .clear)
    .overlay(alignment: .trailing) {
      if !isActive { theme.hairline.frame(width: 0.5).padding(.vertical, 8) }
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
        title: model.title(of: tab), isActive: isActive, isSplit: tab.isSplit, state: state,
        agent: agentID.map(model.agentDisplayName))
    )
    .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction(named: t("action.rename-spoken")) { beginRenaming() }
    .contextMenu {
      TabActions(model: model, group: group, tab: tab, canLeaveGroup: canLeaveGroup)
    }
  }

  /// What the tab is running. A button while there is a state, so a click
  /// clears a stale Working one without activating the tab.
  @ViewBuilder
  private func leadingGlyph(_ state: SessionState?, agentID: String?, text: Color) -> some View {
    let glyph = PaneGlyph(
      agentID: agentID,
      shellSymbol: tab.isSplit ? AgentMarkView.splitSymbol : AgentMarkView.terminalSymbol,
      state: state,
      ringFill: isActive ? theme.backgroundColor : theme.chromeColor,
      plainTint: text,
      theme: theme,
      size: model.metrics.icon + 2)
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
    Button {
      model.closeTab(tab.id)
    } label: {
      Image(systemName: "xmark")
        .font(.system(size: 9, weight: .semibold))
        .frame(width: 20, height: 20)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .foregroundStyle(theme.textSecondary)
    .accessibilityLabel(t("tab.close"))
  }

  /// An empty name clears the custom title rather than storing a blank one;
  /// `InlineNameField` has the keyboard contract.
  private var titleField: some View {
    InlineNameField(
      initial: tab.customTitle ?? model.title(of: tab),
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
