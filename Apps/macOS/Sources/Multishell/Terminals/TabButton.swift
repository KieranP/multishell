import MultishellAppCore
import MultishellCore
import SwiftUI

/// One tab in a column's strip: what it shows, what a click on each part of
/// it does, and both ends of dragging it. `TabBar` places these and decides
/// how wide they are.
struct TabButton: View {
  let model: AppModel
  /// The column this tab sits in, which its own moves are measured against.
  let group: TabGroup
  let tab: TerminalTab
  /// Whether this column is the one the keystrokes go to. Only the focused
  /// column's active tab reads at full strength and carries the close
  /// button; another column's active tab still fills, since it is on screen.
  let isFocused: Bool
  /// Whether the column has another tab, so this one leaving it would be a
  /// move rather than the same layout under a new id.
  let canLeaveColumn: Bool
  /// Whether the tab in the air belongs to this column, so it is moving
  /// along this strip as the pointer goes; the strip works it out once. A
  /// tab from another column has not moved yet, and the line is where it
  /// would land.
  let isShuffling: Bool
  /// Exactly this wide, so the drop can tell which half of it the pointer
  /// is in without measuring; see `TabStripLayout`.
  let width: Double
  let theme: Theme
  @Binding var drag: TabDragState
  /// Which tab in the strip is showing its name field, so only one ever is.
  @Binding var editingTabID: TerminalTab.ID?

  private var isActive: Bool { tab.id == group.activeTabID }
  private var isEditing: Bool { editingTabID == tab.id }

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
        // A drag with no image of its own. AppKit draws the preview itself,
        // as an elevated card, and holds it on screen for the best part of a
        // second after the mouse comes up, wherever the tab landed; nothing
        // in SwiftUI's drag API reaches that disposal, so the only way not
        // to see it is to give it nothing to draw. The tab itself is the
        // preview instead: along its own strip it moves with the pointer
        // while its neighbours make room, and on its way somewhere else it
        // stays put and fades, with the destination lighting up.
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

  /// Where the dragged tab will land, on the tab the pointer is over: its
  /// leading edge for before, its trailing edge for after. The sidebar draws
  /// the same line lying down when projects are reordered.
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
    // The tab in the air. Read from the drop targets rather than from the
    // drag having begun, so a drag let go where nothing saw it cannot leave
    // a tab marked for good. Half there while it slides along its own strip,
    // since it is the thing being carried; fainter once it is waiting to
    // leave for another column or another worktree.
    .opacity(isInTheAir ? (isShuffling ? 0.55 : 0.3) : 1)
    .contentShape(.rect)
    // Simultaneous, not sequential: a plain double-tap recognizer makes
    // SwiftUI hold the single tap until it is sure no second is coming,
    // and tab switching should not lag by that timeout.
    .onTapGesture { model.activate(tab) }
    .simultaneousGesture(TapGesture(count: 2).onEnded { beginEditing() })
    // Every tab strip closes on a middle click, the active one or not.
    .onMiddleClick { model.closeTab(tab.id) }
    // The buttons inside keep their own labels; the row's label describes
    // the tab. `.contain` rather than `.combine`, which would read the
    // close button's label into the tab's.
    .accessibilityElement(children: .contain)
    .accessibilityLabel(
      AccessibilityText.tab(
        title: model.title(of: tab), isActive: isActive, isSplit: tab.isSplit, state: state)
    )
    .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction(named: "Rename") { beginEditing() }
    .contextMenu { menu(state) }
  }

  /// The state dot where there is one, else the tab's kind. A button, so a
  /// click on the dot clears a Working state whose agent is long gone
  /// without activating the tab first.
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
      .help("\(state.displayName). Click to clear.")
      .accessibilityLabel("\(state.displayName). Clear status")
    } else {
      Image(systemName: tab.isSplit ? "rectangle.split.2x1" : "apple.terminal")
        .font(.system(size: model.metrics.icon))
        .foregroundStyle(text)
    }
  }

  /// Names its own tab, like the middle click. `closeActiveTab` is for the
  /// keystroke, which has no target of its own and so has to ask which
  /// window is key first; a click on this X has already answered both.
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
    .accessibilityLabel("Close Tab")
  }

  @ViewBuilder
  private func menu(_ state: SessionState?) -> some View {
    Button("Rename…") { beginEditing() }
    if tab.customTitle != nil {
      Button("Use Shell Title") { model.renameTab(tab.id, to: nil) }
    }
    if state != nil {
      Divider()
      Button("Clear Status") { model.clearState(of: tab) }
    }
    Divider()
    // The keyboard-only way to the layout the edge bands offer a drag.
    // Offered on the tab it names rather than on the active one, and only
    // where it would do something: the sole tab of a column moving out of
    // it is the same layout under a new id.
    Button("Move to New Group") {
      model.moveTab(tab.id, .after, toNewGroupOf: group.id)
    }
    .disabled(!canLeaveColumn)
    Divider()
    // The one way to close a tab that is not the active one without a
    // mouse: the X is drawn on the active tab alone, and the middle click
    // and the keystrokes each want one. Not destructive-red: closing a tab
    // is what a tab strip is for, and a working agent is asked about
    // whichever way the close was asked for.
    Button("Close Tab") { model.closeTab(tab.id) }
  }

  /// An empty name clears the custom title rather than storing a blank one;
  /// `InlineNameField` has the keyboard contract.
  private var titleField: some View {
    InlineNameField(
      initial: tab.customTitle ?? model.title(of: tab),
      prompt: "Tab name",
      font: .system(size: model.metrics.secondary, weight: .medium),
      color: theme.textPrimary,
      commit: { title in
        model.renameTab(tab.id, to: title)
        editingTabID = nil
      },
      cancel: { editingTabID = nil })
  }

  private func beginEditing() {
    editingTabID = tab.id
  }
}
