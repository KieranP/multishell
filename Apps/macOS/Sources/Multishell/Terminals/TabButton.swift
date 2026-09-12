import MultishellAppCore
import MultishellCore
import SwiftUI

/// One tab in a column's strip: what it shows, what a click on each part does,
/// and both ends of dragging it. `TabBar` places and sizes them.
struct TabButton: View {
  let model: AppModel
  /// The column this tab sits in, which its own moves are measured against.
  let group: TabGroup
  let tab: TerminalTab
  /// Whether this column takes the keystrokes. Only its active tab reads at
  /// full strength; another column's still fills, being on screen.
  let isFocused: Bool
  /// Whether the column has another tab, so this one leaving it would be a
  /// move rather than the same layout under a new id.
  let canLeaveColumn: Bool
  /// Whether the tab in the air is this column's, so it moves as the pointer
  /// goes. One from another column has not moved, and the line says where.
  let isShuffling: Bool
  /// Exactly this wide, so the drop can tell which half of it the pointer
  /// is in without measuring; see `TabStripLayout`.
  let width: Double
  let theme: Theme
  @Binding var drag: TabDragState
  /// Which tab in the strip is showing its name field, so only one ever is.

  private var isActive: Bool { tab.id == group.activeTabID }
  private var isEditing: Bool { model.renamingTabID == tab.id }

  private var isInTheAir: Bool {
    drag.tabID == tab.id && drag.isEngaged
  }

  var body: some View {
    face
      .frame(width: width)
      .clipped()
      .overlay(alignment: drag.insertion?.placement == .after ? .trailing : .leading) {
        insertionLine
      }
      .onDrag {
        drag.begin(tab.id)
        return TabTransfer(id: tab.id).itemProvider()
      } preview: {
        // A drag with no image of its own: AppKit holds its preview card
        // for most of a second after the drop, so the tab is the preview.
        Color.clear.frame(width: 1, height: 1)
      }
      .onDrop(
        of: [TabTransfer.contentType],
        delegate: TabDropDelegate(
          tabID: tab.id,
          width: width,
          drag: $drag,
          perform: { moving, placement in model.moveTab(moving, placement, tab.id) },
          shuffle: { moving, placement in
            withAnimation(.easeOut(duration: 0.14)) {
              model.shuffleTab(moving, placement, past: tab.id)
            }
          }
        ))
  }

  /// Where the dragged tab will land, on the tab the pointer is over. The
  /// sidebar draws the same line lying down.
  @ViewBuilder
  private var insertionLine: some View {
    if drag.isDragging, !isShuffling, let insertion = drag.insertion, insertion.tabID == tab.id {
      Capsule()
        .fill(Color.accentColor)
        .frame(width: 2)
        .padding(.vertical, 6)
        .offset(x: insertion.placement == .before ? -1 : 1)
    }
  }

  private var face: some View {
    let isFront = isActive && isFocused
    let text = isFront ? theme.textPrimary : theme.textSecondary
    let state = model.state(of: tab)
    return HStack(spacing: 7) {
      leadingGlyph(state, text: text)

      if isEditing {
        titleField
      } else {
        Text(model.title(of: tab))
          .font(.system(size: model.metrics.secondary, weight: isActive ? .medium : .regular))
          .foregroundStyle(text)
          .lineLimit(1)
          .truncationMode(.tail)
      }

      Spacer(minLength: 0)

      if isFront, !isEditing { closeButton }
    }
    .padding(.horizontal, 10)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(isActive ? theme.backgroundColor : .clear)
    .overlay(alignment: .trailing) {
      if !isActive { theme.hairline.frame(width: 0.5).padding(.vertical, 8) }
    }
    // The tab in the air, read from the drop targets rather than the drag
    // beginning, so one let go unseen cannot mark a tab for good.
    .opacity(isInTheAir ? (isShuffling ? 0.55 : 0.3) : 1)
    .contentShape(.rect)
    // Simultaneous, not sequential: a plain double-tap makes SwiftUI hold
    // the single tap, and switching should not lag by that timeout.
    .onTapGesture { model.activate(tab) }
    .simultaneousGesture(TapGesture(count: 2).onEnded { beginEditing() })
    // Every tab strip closes on a middle click, the active one or not.
    .onMiddleClick { model.closeTab(tab.id) }
    // The buttons inside keep their own labels. `.contain`, not `.combine`,
    // which would read the close button's into the tab's.
    .accessibilityElement(children: .contain)
    .accessibilityLabel(
      AccessibilityText.tab(
        title: model.title(of: tab), isActive: isActive, isSplit: tab.isSplit, state: state)
    )
    .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction(named: t("action.rename-spoken")) { beginEditing() }
    .contextMenu { menu(state) }
  }

  /// The state dot where there is one, else the tab's kind. A button, so a
  /// click clears a stale Working state without activating the tab.
  @ViewBuilder
  private func leadingGlyph(_ state: SessionState?, text: Color) -> some View {
    if let state {
      Button {
        model.clearState(of: tab)
      } label: {
        Circle().fill(theme.color(for: state)).frame(width: 7, height: 7)
          .frame(width: 14, height: 14)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .help(t("tab.state-click-to-clear", state.displayName))
      .accessibilityLabel(t("tab.state-clear-status", state.displayName))
    } else {
      Image(systemName: tab.isSplit ? "rectangle.split.2x1" : "apple.terminal")
        .font(.system(size: model.metrics.icon))
        .foregroundStyle(text)
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

  @ViewBuilder
  private func menu(_ state: SessionState?) -> some View {
    Button(t("action.rename")) { beginEditing() }
    if tab.customTitle != nil {
      Button(t("tab.use-shell-title")) { model.renameTab(tab.id, to: nil) }
    }
    if state != nil {
      Divider()
      Button(t("actions.clear-status")) { model.clearState(of: tab) }
    }
    Divider()
    // The keyboard-only way to the layout the edge bands offer a drag, and
    // only where it would do something.
    Button(t("tab.move-to-new-group")) {
      model.moveTab(tab.id, .after, toNewGroupOf: group.id)
    }
    .disabled(!canLeaveColumn)
    Divider()
    // The one way to close an inactive tab without a mouse, the X being
    // drawn on the active one alone. Not destructive-red.
    Button(t("tab.close")) { model.closeTab(tab.id) }
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

  private func beginEditing() {
    model.beginRenamingTab(tab.id)
  }
}
