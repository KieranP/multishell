import MultishellAppCore
import MultishellCore
import SwiftUI

struct TabBar: View {
  let model: AppModel
  let tabs: [TerminalTab]
  let activeID: TerminalTab.ID?
  let theme: Theme

  @State private var editingTabID: TerminalTab.ID?
  @State private var draggingTab: TerminalTab.ID?
  @State private var dropTarget: TabDropTarget?
  /// Each tab's width, which the drop delegate halves to decide which side
  /// of it the line goes. Measured rather than assumed: tabs share the
  /// strip's width up to a cap, so no two need be the same size.
  @State private var tabWidths: [TerminalTab.ID: CGFloat] = [:]

  var body: some View {
    HStack(spacing: 0) {
      ForEach(tabs) { tab in
        tabButton(tab)
          .frame(maxWidth: 190)
          .background { widthReader(tab) }
          .overlay(alignment: dropTarget?.placement == .after ? .trailing : .leading) {
            insertionLine(tab)
          }
          .onDrag {
            draggingTab = tab.id
            return TabTransfer(id: tab.id).itemProvider()
          }
          .onDrop(
            of: [TabTransfer.contentType],
            delegate: TabDropDelegate(
              tabID: tab.id,
              width: tabWidths[tab.id] ?? 0,
              target: $dropTarget,
              perform: { placement in
                if let moving = draggingTab { model.moveTab(moving, placement, tab.id) }
                endDrag()
              }
            ))
      }
      // New tab sits with the tabs. With no tabs there is no strip, and the
      // header's actions menu or Cmd+T takes over.
      Button {
        model.newTab()
      } label: {
        Image(systemName: "plus")
          .font(.system(size: model.metrics.icon, weight: .medium))
          .foregroundStyle(theme.textSecondary)
          .frame(width: 34, height: model.metrics.tabHeight)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .help("New Tab (⌘T)")
      .accessibilityLabel("New Tab")

      Spacer(minLength: 0)
    }
    .frame(height: model.metrics.tabHeight)
    .background(theme.chromeColor)
    .overlay(alignment: .top) { theme.hairline.frame(height: 0.5) }
    // A drop that misses every tab, on the new-tab button or the empty
    // space beyond, still ends the drag, so the line and the dragged id are
    // cleared here rather than left over for the next render.
    .onDrop(of: [TabTransfer.contentType], isTargeted: nil) { _ in
      endDrag()
      return false
    }
  }

  private func endDrag() {
    dropTarget = nil
    draggingTab = nil
  }

  /// Where the dragged tab will land, on the tab the pointer is over: its
  /// leading edge for before, its trailing edge for after. The sidebar draws
  /// the same line lying down when projects are reordered.
  @ViewBuilder
  private func insertionLine(_ tab: TerminalTab) -> some View {
    if draggingTab != nil, let target = dropTarget, target.tabID == tab.id {
      Capsule()
        .fill(Color.accentColor)
        .frame(width: 2)
        .padding(.vertical, 6)
        .offset(x: target.placement == .before ? -1 : 1)
    }
  }

  /// A closed tab's width is left behind rather than cleared on disappear:
  /// nothing orders that against the appear of a tab arriving in the same
  /// pass, and a width cleared after it was measured reads as unmeasured,
  /// which puts every line on the leading edge. A stale entry is never read.
  private func widthReader(_ tab: TerminalTab) -> some View {
    GeometryReader { proxy in
      Color.clear
        .onAppear { tabWidths[tab.id] = proxy.size.width }
        .onChange(of: proxy.size.width) { _, width in tabWidths[tab.id] = width }
    }
  }

  private func tabButton(_ tab: TerminalTab) -> some View {
    let isActive = tab.id == activeID
    let text = isActive ? theme.textPrimary : theme.textSecondary
    let state = model.state(of: tab)
    return HStack(spacing: 7) {
      if let state {
        // A button, so a click on the dot clears a Working state whose agent
        // is long gone without activating the tab first.
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

      if editingTabID == tab.id {
        titleField(tab)
      } else {
        Text(model.title(of: tab))
          .font(.system(size: model.metrics.secondary, weight: isActive ? .medium : .regular))
          .foregroundStyle(text)
          .lineLimit(1)
          .truncationMode(.tail)
      }

      Spacer(minLength: 0)

      if isActive, editingTabID != tab.id {
        // Names its own tab, like the middle click. `closeActiveTab` is for
        // the keystroke, which has no target of its own and so has to ask
        // which window is key first; a click on this X has already answered
        // both questions.
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
    }
    .padding(.horizontal, 10)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(isActive ? theme.backgroundColor : .clear)
    .overlay(alignment: .trailing) {
      if !isActive { theme.hairline.frame(width: 0.5).padding(.vertical, 8) }
    }
    .contentShape(.rect)
    // Simultaneous, not sequential: a plain double-tap recognizer makes
    // SwiftUI hold the single tap until it is sure no second is coming,
    // and tab switching should not lag by that timeout.
    .onTapGesture { model.activate(tab) }
    .simultaneousGesture(TapGesture(count: 2).onEnded { beginEditing(tab) })
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
    .accessibilityAction(named: "Rename") { beginEditing(tab) }
    .contextMenu {
      Button("Rename…") { beginEditing(tab) }
      if tab.customTitle != nil {
        Button("Use Shell Title") { model.renameTab(tab.id, to: nil) }
      }
      if state != nil {
        Divider()
        Button("Clear Status") { model.clearState(of: tab) }
      }
      Divider()
      // The one way to close a tab that is not the active one without a
      // mouse: the X is drawn on the active tab alone, and the middle click
      // and the keystrokes each want one. Not destructive-red: closing a tab
      // is what a tab strip is for, and a working agent is asked about
      // whichever way the close was asked for.
      Button("Close Tab") { model.closeTab(tab.id) }
    }
  }

  /// An empty name clears the custom title rather than storing a blank one;
  /// `InlineNameField` has the keyboard contract.
  private func titleField(_ tab: TerminalTab) -> some View {
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

  private func beginEditing(_ tab: TerminalTab) {
    editingTabID = tab.id
  }
}
