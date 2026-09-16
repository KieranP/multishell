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
      // What the tabs share, the strip's buttons taken off, and from it one
      // width for all of them, so a drop needs no measuring. The splits go
      // where they would leave no room for a tab, so both halves of this
      // read the width the same way.
      let width = Double(proxy.size.width)
      let showsSplits = model.metrics.stripShowsSplits(in: width)
      let available =
        width - (showsSplits ? model.metrics.stripButtonsWidth : model.metrics.newTabMenuWidth)
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
            activeID: group.activeTabID
          ) {
            tabViews(layout)
          }
          stripButtons(showsSplits)
        } else {
          HStack(spacing: 0) { tabViews(layout) }
          stripButtons(showsSplits)
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
        drag: $drag)
    }
  }

  /// New Tab and the two splits, each naming this column, so a click in one
  /// never acts in another. Outside the scroller, so a full strip cannot
  /// hide them.
  private func stripButtons(_ showsSplits: Bool) -> some View {
    HStack(spacing: 0) {
      newTabMenu
      if showsSplits {
        // The same family the tab's own icon uses for a split tab.
        splitButton(.horizontal, symbol: "rectangle.split.2x1")
        splitButton(.vertical, symbol: "rectangle.split.1x2")
      }
    }
  }

  /// A shell, then every agent found on the PATH. What ⌘T does, which turns
  /// on auto-start, is not among them: each item here says what it starts.
  private var newTabMenu: some View {
    Menu {
      Button(t("menu.new-shell-tab")) { model.newShellTab(in: group.id) }
      ForEach(model.installedAgentIDs, id: \.self) { id in
        Button(itemTitle(id)) { model.newAgentTab(id, in: group.id) }
      }
    } label: {
      newTabLabel
    }
    // Not `.borderlessButton`: that one is an AppKit button, which keeps one
    // image of the label and drops the chevron. See docs/design/tabs-and-columns.md.
    .menuStyle(.button)
    .buttonStyle(.plain)
    .menuIndicator(.hidden)
    .frame(width: model.metrics.newTabMenuWidth, height: model.metrics.tabHeight)
    // Every item opens in this column. Only the focused one need not say so,
    // being where the keyboard already is.
    .help(isFocused ? t("tab.new") : t("tab.new-in-group"))
    .accessibilityLabel(t("tab.new"))
  }

  /// The plus and the chevron that says it opens a menu. Painted, not a
  /// `contentShape`: a menu is hit-tested by what its label draws, so a
  /// clear frame around the glyphs would not be part of the target.
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

  /// "New Claude Code Tab", and the typed command by its own name rather
  /// than as "New Custom command Tab".
  private func itemTitle(_ id: String) -> String {
    id == AgentCatalogue.customID
      ? t("tab.new-custom-agent") : t("tab.new-named-agent", model.agentDisplayName(id))
  }

  /// Splits the tab this column shows, whichever column the keyboard is in.
  private func splitButton(_ axis: SplitAxis, symbol: String) -> some View {
    Button {
      model.splitActivePane(axis, in: group.id)
    } label: {
      stripIcon(symbol)
    }
    .buttonStyle(.plain)
    .help(help(for: axis))
    .accessibilityLabel(axis == .horizontal ? t("tab.split-right") : t("tab.split-down"))
  }

  /// The keystrokes split the focused column, so only that column's buttons
  /// are what they do.
  private func help(for axis: SplitAxis) -> String {
    switch (axis, isFocused) {
    case (.horizontal, true): t("tab.split-right-here")
    case (.horizontal, false): t("tab.split-right-in-group")
    case (.vertical, true): t("tab.split-down-here")
    case (.vertical, false): t("tab.split-down-in-group")
    }
  }

  private func stripIcon(_ symbol: String) -> some View {
    Image(systemName: symbol)
      .font(.system(size: model.metrics.icon, weight: .medium))
      .foregroundStyle(theme.textSecondary)
      .frame(width: model.metrics.newTabWidth, height: model.metrics.tabHeight)
      .contentShape(.rect)
  }
}
