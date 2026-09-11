import MultishellAppCore
import MultishellCore
import SwiftUI

/// One column's tab strip: how wide its tabs are, whether it scrolls, and
/// what a drop missing every tab means. `TabButton` is one tab in one.
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

  /// Whether the tab in the air is this column's, in which case it moves as
  /// the pointer goes and needs no line. Once for the strip, not per tab.
  private var isShuffling: Bool {
    guard let dragged = drag.tabID else { return false }
    return tabs.contains { $0.id == dragged }
  }

  var body: some View {
    named(strip)
  }

  /// A worktree with one column has nothing to tell apart, so its strip is
  /// no container a screen reader must step into.
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
      // What the tabs share, the New Tab button taken off, and from it one
      // width for all of them, so a drop needs no measuring.
      let available = Double(proxy.size.width) - model.metrics.newTabWidth
      let layout = TabStripLayout(
        available: available,
        count: tabs.count,
        minimum: model.metrics.tabMinWidth,
        maximum: model.metrics.tabMaxWidth)
      HStack(spacing: 0) {
        if layout.scrolls {
          // The scroller takes the whole strip and the button is pinned
          // after it. Not a `Spacer`, which would halve the strip.
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
    // The strip past its last tab, otherwise the one part of a column a
    // click does nothing in. The tabs are hit first.
    .onTapGesture { if !isFocused { model.focusGroup(group.id) } }
    // A drop missing every tab moves it to the end of this column, and ends
    // the drag, as every drop path must.
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

  /// New Tab names this column, so a click in one never opens a tab in
  /// another. Outside the scroller, so a full strip cannot hide it.
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
