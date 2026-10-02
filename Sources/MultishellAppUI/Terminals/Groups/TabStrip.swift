import MultishellAppCore
import MultishellCore
import SwiftUI

/// One group's tab strip: how wide its tabs are, whether it scrolls, and
/// what a drop missing every tab means. `DraggableTab` is one tab in one.
struct TabStrip: View {
  let model: AppModel
  let group: TabGroup
  let tabs: [TerminalTab]
  let isFocusedGroup: Bool
  /// What a screen reader says before this strip's tabs; empty for a
  /// worktree with one group. See `AccessibilityText.tabGroup`.
  let groupLabel: String
  let theme: Theme
  @Binding var drag: TabDragState

  /// Once for the strip, not per tab.
  private var isShuffling: Bool { drag.isShuffling(within: tabs.map(\.id)) }

  var body: some View {
    labelledAsGroup(strip)
  }

  /// A worktree with one group has nothing to tell apart, so its strip is
  /// no container a screen reader must step into.
  @ViewBuilder
  private func labelledAsGroup(_ strip: some View) -> some View {
    if groupLabel.isEmpty {
      strip
    } else {
      strip
        .accessibilityElement(children: .contain)
        .accessibilityLabel(groupLabel)
    }
  }

  private var strip: some View {
    GeometryReader { proxy in
      // One width for every tab, the strip's buttons taken off, so a drop
      // needs no measuring and both halves below read the width alike.
      let width = Double(proxy.size.width)
      let showsSplits = model.metrics.tabStrip.showsSplits(in: width)
      let available = model.metrics.tabStrip.tabsAvailable(in: width)
      let layout = TabStripLayout(
        available: available,
        count: tabs.count,
        minimum: model.metrics.tabMinWidth,
        maximum: model.metrics.tabMaxWidth)
      HStack(spacing: 0) {
        if layout.scrolls {
          // The scroller takes the whole strip and the buttons are pinned
          // after it. Not a `Spacer`, which would halve the strip.
          ScrollingTabStrip(
            model: model,
            theme: theme,
            layout: layout,
            available: available,
            tabIDs: tabs.map(\.id),
            shownTabID: group.shownTabID
          ) {
            tabViews(layout)
          }
          buttons(showsSplits: showsSplits)
        } else {
          HStack(spacing: 0) { tabViews(layout) }
          buttons(showsSplits: showsSplits)
          Spacer(minLength: 0)
        }
      }
      .frame(height: model.metrics.tabHeight)
    }
    .frame(height: model.metrics.tabHeight)
    .background(theme.chromeColor)
    .hairline(.top, theme)
    .contentShape(.rect)
    // The strip past its last tab, otherwise the one part of a group a
    // click does nothing in. The tabs are hit first.
    .onTapGesture { if !isFocusedGroup { model.focusGroup(group.id) } }
    // A drop missing every tab moves one from another group to the end of
    // this one, and ends the drag, as every drop path must.
    .onDrop(
      of: [TabTransfer.contentType],
      delegate: TabStripDropDelegate(drop: { model.dropDraggedTab(on: .strip(group.id)) })
    )
  }

  private func buttons(showsSplits: Bool) -> some View {
    TabStripButtons(
      model: model, groupID: group.id, isFocusedGroup: isFocusedGroup,
      showsSplits: showsSplits, theme: theme)
  }

  @ViewBuilder
  private func tabViews(_ layout: TabStripLayout) -> some View {
    ForEach(tabs) { tab in
      DraggableTab(
        model: model,
        group: group,
        tab: tab,
        isFocusedGroup: isFocusedGroup,
        canLeaveGroup: model.canMoveTabToNewGroup(tab),
        isShuffling: isShuffling,
        width: layout.tabWidth,
        theme: theme,
        drag: $drag
      )
      .equatable()
    }
  }
}
