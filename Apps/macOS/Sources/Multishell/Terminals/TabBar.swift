import MultishellAppCore
import MultishellCore
import SwiftUI

/// One column's tab strip: how wide its tabs are, whether it scrolls, and
/// what a drop that misses every tab means. A worktree with two columns
/// draws two of these; `TabGroupsView` places them, and `TabButton` is one
/// tab in one of them.
struct TabBar: View {
  let model: AppModel
  let group: TabGroup
  let tabs: [TerminalTab]
  /// Whether this column is the one the keystrokes go to.
  let isFocused: Bool
  /// What a screen reader says before this strip's tabs; empty for a
  /// worktree with one column. See `AccessibilityText.tabGroup`.
  let columnLabel: String
  let theme: Theme
  @Binding var drag: TabDragState

  @State private var editingTabID: TerminalTab.ID?

  /// Whether the tab in the air is one of this column's, in which case it is
  /// moving along this strip as the pointer goes and needs no line drawn for
  /// it. Answered from the tabs the strip already holds, once for the strip:
  /// asking per tab would scan every tab in the workspace for each of them.
  private var isShuffling: Bool {
    guard let dragged = drag.tabID else { return false }
    return tabs.contains { $0.id == dragged }
  }

  var body: some View {
    named(strip)
  }

  /// A worktree with one column has nothing to tell apart, so its strip is
  /// not made a container a screen reader has to step into. See
  /// `AccessibilityText.tabGroup`, which is empty in that case.
  @ViewBuilder
  private func named(_ strip: some View) -> some View {
    if columnLabel.isEmpty {
      strip
    } else {
      strip
        .accessibilityElement(children: .contain)
        .accessibilityLabel(columnLabel)
    }
  }

  private var strip: some View {
    GeometryReader { proxy in
      // What the tabs have to share, the New Tab button's own width taken
      // off, and from it the width of every tab: one width for all of them,
      // so a drop can tell which half of one the pointer is in without
      // measuring. See `TabStripLayout`.
      let available = Double(proxy.size.width) - model.metrics.newTabWidth
      let layout = TabStripLayout(
        available: available,
        count: tabs.count,
        minimum: model.metrics.tabMinWidth,
        maximum: model.metrics.tabMaxWidth)
      HStack(spacing: 0) {
        if layout.scrolls {
          // The scroller takes the whole strip and the button is pinned
          // after it. Not a `Spacer` beside them: a scroller and a spacer
          // are both infinitely flexible, and the stack would divide the
          // strip between the two.
          ScrollingTabStrip(
            model: model,
            theme: theme,
            layout: layout,
            available: available,
            tabIDs: tabs.map(\.id),
            activeID: group.activeTabID
          ) {
            tabViews(layout)
          }
          newTabButton
        } else {
          HStack(spacing: 0) { tabViews(layout) }
          newTabButton
          Spacer(minLength: 0)
        }
      }
      .frame(height: model.metrics.tabHeight)
    }
    .frame(height: model.metrics.tabHeight)
    .background(theme.chromeColor)
    .overlay(alignment: .top) { theme.hairline.frame(height: 0.5) }
    .contentShape(.rect)
    // The strip past its last tab, which is otherwise the one part of a
    // column a click does nothing in. The tabs and the New Tab button are
    // hit first and keep their own actions.
    .onTapGesture { if !isFocused { model.focusGroup(group.id) } }
    // A drop that misses every tab, on the new-tab button or the empty
    // space beyond, moves the tab to the end of this column. It also ends
    // the drag, as every drop path must: a line left behind would be drawn
    // over the next render.
    .onDrop(
      of: [TabTransfer.contentType],
      delegate: TabStripDropDelegate(
        drag: $drag,
        perform: { moving in model.moveTab(moving, toEndOf: group.id) })
    )
  }

  @ViewBuilder
  private func tabViews(_ layout: TabStripLayout) -> some View {
    ForEach(tabs) { tab in
      TabButton(
        model: model,
        group: group,
        tab: tab,
        isFocused: isFocused,
        canLeaveColumn: tabs.count > 1,
        isShuffling: isShuffling,
        width: layout.tabWidth,
        theme: theme,
        drag: $drag,
        editingTabID: $editingTabID)
    }
  }

  /// New tab sits with the tabs and names this column, so a click in one
  /// column never opens a tab in another. Outside the scroller, so a full
  /// strip cannot push it out of reach. With no tabs there is no strip, and
  /// the header's actions menu or Cmd+T takes over.
  private var newTabButton: some View {
    Button {
      model.newTab(in: group.id)
    } label: {
      Image(systemName: "plus")
        .font(.system(size: model.metrics.icon, weight: .medium))
        .foregroundStyle(theme.textSecondary)
        .frame(width: model.metrics.newTabWidth, height: model.metrics.tabHeight)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    // The keystroke opens in the focused column, so only that column's
    // button is the thing ⌘T does.
    .help(isFocused ? t("tab.new-here") : t("tab.new-in-group"))
    .accessibilityLabel(t("tab.new"))
  }
}
