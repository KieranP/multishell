import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite
struct UIMetricsTests {
  @Test func theBoardScrollsOnlyOnceItsGapsAndPaddingLeaveAColumnUnderItsFloor() {
    let metrics = UIMetrics(fontSize: 13)
    let fits = 4 * metrics.boardColumnMinWidth + 3 * metrics.boardGap + 2 * metrics.boardPadding
    #expect(!metrics.boardLayout(forWidth: fits, count: 4).scrolls)
    #expect(metrics.boardLayout(forWidth: fits - 1, count: 4).scrolls)
  }

  @Test func everySizeGrowsWithTheBase() {
    let small = UIMetrics(fontSize: 11)
    let large = UIMetrics(fontSize: 16)
    for keyPath in [
      \UIMetrics.bodySize, \.secondary, \.caption, \.badge, \.monospaced, \.glyph, \.rowHeight,
      \.customNameRowHeight, \.tabHeight, \.tabCloseButtonSide, \.worktreeRowIndent,
      \.paneRowHeight, \.findControlSize,
    ] {
      #expect(small[keyPath: keyPath] < large[keyPath: keyPath])
    }
  }

  /// Written out rather than recomputed from `UIMetrics`: with the same
  /// expression on both sides the test cannot see the widths change.
  @Test func theSplitsShowAtTheThresholdAndNotAPointEarlier() {
    for (size, threshold) in [(10.0, 202.0), (13.0, 252.0), (18.0, 351.0)] {
      let metrics = UIMetrics(fontSize: size)
      #expect(metrics.tabStripWidths.showsSplits(in: threshold), "the splits never show at \(size)")
      #expect(
        !metrics.tabStripWidths.showsSplits(in: threshold - 1),
        "the splits show a point early at \(size)"
      )
    }
  }

  @Test func aStripsTabsHaveWhatItsButtonsLeave() {
    let metrics = UIMetrics(fontSize: 13)
    #expect(
      metrics.tabStripWidths.tabsAvailable(in: 252) == 145, "the menu and both splits come off")
    #expect(
      metrics.tabStripWidths.tabsAvailable(in: 251) == 212,
      "only the menu comes off below the threshold")
  }

  @Test func aScrollingStripHasGuttersOnlyWithRoomForBothAndATab() {
    let metrics = UIMetrics(fontSize: 13)
    #expect(metrics.tabStripWidths.arrowGutter(forAvailable: 145) == 22)
    #expect(metrics.tabStripWidths.arrowGutter(forAvailable: 144) == 0)
  }

  @Test func aScrollingStripsViewportIsWhatItsTwoGuttersLeave() {
    let metrics = UIMetrics(fontSize: 13)
    #expect(metrics.tabStripWidths.scrollingViewport(forAvailable: 145) == 101)
    #expect(metrics.tabStripWidths.scrollingViewport(forAvailable: 144) == 144)
  }

  @Test func aProjectsBlockIsItsRowAndEachWorktreesWithTheSelectedOnesPanes() {
    let metrics = UIMetrics(fontSize: 13)

    let plain = Worktree(path: URL(fileURLWithPath: "/repo"), projectID: "/repo", head: "a")
    let named = Worktree(path: URL(fileURLWithPath: "/repo/b"), projectID: "/repo", head: "b")
    let pane = SidebarPane(
      id: UUID(), title: "zsh", position: nil, isFocused: false, state: nil, workers: [],
      agentID: nil, agentName: nil)

    let height = metrics.projectBlockHeight(worktreeRows: [
      SidebarWorktree(worktree: plain, customName: nil, isRenaming: false, panes: []),
      SidebarWorktree(worktree: named, customName: "B", isRenaming: false, panes: [pane, pane]),
    ])

    #expect(height == 148)
  }

  @Test func aCornerBadgeIsSixTenthsOfItsGlyphInWholePointsAndNeverUnderSeven() {
    #expect(UIMetrics.cornerBadgeSize(onGlyphOf: 8) == 7)
    #expect(UIMetrics.cornerBadgeSize(onGlyphOf: 13) == 8)
    #expect(UIMetrics.cornerBadgeSize(onGlyphOf: 16) == 10)
  }

  @Test func rowsAreTallEnoughForTheirText() {
    for size in stride(
      from: Appearance.uiFontSizes.lowerBound, through: Appearance.uiFontSizes.upperBound, by: 1
    ) {
      let metrics = UIMetrics(fontSize: size)
      #expect(metrics.rowHeight >= metrics.bodySize * 1.8, "size \(size)")
      #expect(
        metrics.customNameRowHeight >= metrics.rowHeight + metrics.badge,
        "a named row holds a branch line under the name at \(size)")
      #expect(metrics.badge >= 7, "badge text must stay legible at \(size)")
      #expect(
        metrics.paneRowHeight >= metrics.badge * 1.8 && metrics.paneRowHeight < metrics.rowHeight,
        "a pane's row holds its badge text and sits under a worktree's at \(size)")
    }
  }

  /// A tab's floor has to hold what the active one draws: side padding, the
  /// mark, a gap either side of the title and the spacer, the close button.
  @Test func aTabStripsMeasuresHoldWhatTheyDrawAtEverySize() {
    for size in stride(
      from: Appearance.uiFontSizes.lowerBound, through: Appearance.uiFontSizes.upperBound, by: 1
    ) {
      let metrics = UIMetrics(fontSize: size)
      let furniture =
        UIMetrics.tabSideInset * 2 + metrics.paneGlyphSize + UIMetrics.tabItemGap * 3
        + metrics.tabCloseButtonSide
      #expect(
        metrics.tabMinWidth >= furniture + metrics.bodySize * 2,
        "no room for a title at \(size)")
      #expect(metrics.tabMinWidth < metrics.tabMaxWidth, "size \(size)")
      #expect(metrics.splitButtonWidth >= metrics.glyph * 2, "a split needs a target at \(size)")
      #expect(
        metrics.newTabMenuWidth
          >= metrics.stripGlyphInset + metrics.glyph + UIMetrics.menuChevronGap
          + metrics.menuChevronSize,
        "the plus and its chevron overrun the menu at \(size)")
      #expect(metrics.menuChevronSize < metrics.glyph, "the chevron reads as a mark at \(size)")
      #expect(
        metrics.stripButtonsWidth == metrics.newTabMenuWidth + metrics.splitButtonWidth * 2,
        "the New Tab menu and the two splits are taken off the strip at \(size)")
      #expect(
        !metrics.tabStripWidths.showsSplits(in: UIMetrics.minimumPaneLength),
        "a group at its floor has no room for the splits at \(size)")
      // The width they first show at has to leave the scroller its gutters,
      // else the splits are bought by scrolling a strip with no arrows.
      let showsAt = metrics.stripButtonsWidth + 2 * metrics.tabArrowWidth + metrics.tabMinWidth
      #expect(metrics.tabStripWidths.showsSplits(in: showsAt), "the splits never show at \(size)")
      #expect(
        !metrics.tabStripWidths.showsSplits(in: showsAt - 1),
        "the splits show a point early at \(size)")
      #expect(
        showsAt - metrics.stripButtonsWidth >= 2 * metrics.tabArrowWidth + metrics.tabMinWidth,
        "the splits cost the strip its arrows at \(size)")
      #expect(
        metrics.tabArrowWidth >= metrics.bodySize,
        "the scroll arrow's own glyph does not fit at \(size)")
      #expect(
        metrics.tabMinWidth > 2 * metrics.tabArrowWidth,
        "two gutters must leave room for a tab at \(size)")
    }
  }
}
