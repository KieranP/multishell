import Testing

@testable import MultishellAppUI

@Suite
struct UIMetricsTests {
  @Test func everySizeGrowsWithTheBase() {
    let small = UIMetrics(fontSize: 11)
    let large = UIMetrics(fontSize: 16)
    for keyPath in [
      \UIMetrics.body, \.secondary, \.caption, \.badge, \.mono, \.icon, \.rowHeight,
      \.namedRowHeight, \.tabHeight, \.indent, \.paneRowHeight, \.findControlSize,
    ] {
      #expect(small[keyPath: keyPath] < large[keyPath: keyPath])
    }
  }

  /// Written out rather than recomputed from `UIMetrics`: with the same
  /// expression on both sides the test cannot see the widths change.
  @Test func theSplitThresholdIsTheWidthTheDocsQuote() {
    for (size, threshold) in [(10.0, 193.0), (13.0, 252.0), (18.0, 351.0)] {
      let metrics = UIMetrics(fontSize: size)
      #expect(metrics.stripShowsSplits(in: threshold), "the splits never show at \(size)")
      #expect(
        !metrics.stripShowsSplits(in: threshold - 1), "the splits show a point early at \(size)")
    }
  }

  @Test func aStripsTabsHaveWhatItsButtonsLeave() {
    let metrics = UIMetrics(fontSize: 13)
    #expect(metrics.stripTabRoom(in: 252) == 145, "the menu and both splits come off")
    #expect(metrics.stripTabRoom(in: 251) == 212, "only the menu comes off below the threshold")
  }

  @Test func aScrollingStripHasGuttersOnlyWithRoomForBothAndATab() {
    let metrics = UIMetrics(fontSize: 13)
    #expect(metrics.tabArrowGutter(forRoom: 145) == 22)
    #expect(metrics.tabArrowGutter(forRoom: 144) == 0)
  }

  @Test func aProjectsBlockIsItsRowAndEachWorktreesWithTheSelectedOnesPanes() {
    let metrics = UIMetrics(fontSize: 13)

    let height = metrics.projectBlockHeight(worktreeRows: [
      (isNamed: false, isRenaming: false, paneCount: 0),
      (isNamed: true, isRenaming: false, paneCount: 2),
    ])

    #expect(height == 148)
  }

  @Test func rowsAreTallEnoughForTheirText() {
    for size in stride(from: 10.0, through: 18.0, by: 1) {
      let metrics = UIMetrics(fontSize: size)
      #expect(metrics.rowHeight >= metrics.body * 1.8, "size \(size)")
      #expect(
        metrics.namedRowHeight >= metrics.rowHeight + metrics.badge,
        "a named row holds a branch line under the name at \(size)")
      #expect(metrics.badge >= 7, "badge text must stay legible at \(size)")
      #expect(
        metrics.paneRowHeight >= metrics.badge * 1.8 && metrics.paneRowHeight < metrics.rowHeight,
        "a pane's row holds its badge text and sits under a worktree's at \(size)")
    }
  }

  /// A tab's floor has to hold what it always draws: side padding, the mark,
  /// the gap, the close button, and something over for the title.
  @Test func theNarrowestTabStillHasRoomForItsTitle() {
    for size in stride(from: 10.0, through: 18.0, by: 1) {
      let metrics = UIMetrics(fontSize: size)
      let furniture = 20.0 + (metrics.icon + 2) + 7 + 20
      #expect(
        metrics.tabMinWidth >= furniture + metrics.body * 2,
        "no room for a title at \(size)")
      #expect(metrics.tabMinWidth < metrics.tabMaxWidth, "size \(size)")
      #expect(metrics.splitButtonWidth >= metrics.icon * 2, "a split needs a target at \(size)")
      #expect(
        metrics.newTabMenuWidth
          >= metrics.stripGlyphInset + metrics.icon + metrics.menuChevronGap + metrics.menuChevron,
        "the plus and its chevron overrun the menu at \(size)")
      #expect(metrics.menuChevron < metrics.icon, "the chevron reads as a mark at \(size)")
      #expect(
        metrics.stripButtonsWidth == metrics.newTabMenuWidth + metrics.splitButtonWidth * 2,
        "the New Tab menu and the two splits are taken off the strip at \(size)")
      #expect(
        !metrics.stripShowsSplits(in: UIMetrics.minimumPaneLength),
        "a group at its floor has no room for the splits at \(size)")
      // The width they first show at has to leave the scroller its gutters,
      // else the splits are bought by scrolling a strip with no arrows.
      let showsAt = metrics.stripButtonsWidth + 2 * metrics.tabArrowWidth + metrics.tabMinWidth
      #expect(metrics.stripShowsSplits(in: showsAt), "the splits never show at \(size)")
      #expect(
        !metrics.stripShowsSplits(in: showsAt - 1),
        "the splits show a point early at \(size)")
      #expect(
        showsAt - metrics.stripButtonsWidth >= 2 * metrics.tabArrowWidth + metrics.tabMinWidth,
        "the splits cost the strip its arrows at \(size)")
      #expect(
        metrics.tabArrowWidth >= metrics.body,
        "the scroll arrow's own glyph does not fit at \(size)")
      #expect(
        metrics.tabMinWidth > 2 * metrics.tabArrowWidth,
        "two gutters must leave room for a tab at \(size)")
    }
  }
}
