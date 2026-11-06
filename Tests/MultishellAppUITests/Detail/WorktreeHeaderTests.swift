import AppKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct WorktreeHeaderTests {
  /// Text drawn at another fraction of a point inks a point more or less; a cut
  /// name loses a character's width, about seven.
  private static let subpixelSlack = 2
  /// The gaps, the spacer, the ⋯ menu, the Files toggle and the header's inset
  /// after the last text, about 102 pt, with a few to spare.
  private static let headerEndAfterTheText = 110.0
  /// macOS 27.0 leaves 4 pt unlit inside a branch name; the header's parts sit
  /// 16 pt apart.
  private static let widestGapInsideAText = 8

  @Test func aMissingProjectsBadgeIsRingedInTheHeadersColourNotTheSidebars() throws {
    let harness = ModelHarness()
    let worktree = harness.addPrimaryWorktree()
    let theme = Theme.multishellDark
    func header() throws -> NSBitmapImageRep {
      try #require(
        OffscreenWindow.pixels(
          ofHosted: WorktreeHeader(model: harness.model, worktree: worktree, theme: theme),
          size: CGSize(width: 600, height: 40),
        )
      )
    }
    let unbadged = try header()
    harness.model.missingProjects = [harness.project.id]
    let bitmap = try header()
    #expect(bitmap.tiffRepresentation != unbadged.tiffRepresentation, "a badge is drawn")
    let sidebarColour = try #require(
      NSColor(theme.projectsPanel.background).usingColorSpace(bitmap.colorSpace)
    )
    func isSidebarColour(_ x: Int, _ y: Int) -> Bool {
      guard let pixel = bitmap.colorAt(x: x, y: y) else { return false }
      return abs(pixel.redComponent - sidebarColour.redComponent) < 0.004
        && abs(pixel.greenComponent - sidebarColour.greenComponent) < 0.004
        && abs(pixel.blueComponent - sidebarColour.blueComponent) < 0.004
    }
    let filledInSidebarColour = (1..<bitmap.pixelsWide - 1).flatMap { x in
      (1..<bitmap.pixelsHigh - 1).filter { y in
        [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)].allSatisfy { isSidebarColour(x + $0, y + $1) }
      }
    }

    #expect(
      filledInSidebarColour.isEmpty,
      "\(filledInSidebarColour.count) pixels filled in the sidebar's colour",
    )
  }

  /// Where the parts drawn in `key` sit, in points: glyphs no further apart than
  /// a gap inside one text make one run.
  private func inkRuns(
    inHeaderOfWidth width: Double,
    showing worktree: Worktree,
    in harness: ModelHarness,
    of key: InterfaceColorKey = .textTertiary,
  ) throws -> [ClosedRange<Int>] {
    let theme = try MagentaTheme.with([.header: [key]])
    let bitmap = try #require(
      OffscreenWindow.pixels(
        ofHosted: WorktreeHeader(model: harness.model, worktree: worktree, theme: theme),
        size: CGSize(width: width, height: 40),
      )
    )
    let pixelsPerPoint = bitmap.pixelsWide / Int(width)
    let gapBetweenGlyphs = Self.widestGapInsideAText * pixelsPerPoint
    let pixelRuns: [ClosedRange<Int>] = MagentaTheme.inkedColumns(in: bitmap)
      .reduce(into: []) { runs, x in
        if let last = runs.last, x - last.upperBound <= gapBetweenGlyphs {
          runs[runs.count - 1] = last.lowerBound...x
        } else {
          runs.append(x...x)
        }
      }
    return pixelRuns.map { ($0.lowerBound / pixelsPerPoint)...($0.upperBound / pixelsPerPoint) }
  }

  private func worktreeAtAShortPath(in harness: ModelHarness) -> Worktree {
    let primary = harness.addPrimaryWorktree()
    let short = Worktree(
      path: URL(fileURLWithPath: "/w"),
      projectID: harness.project.id,
      head: "abc1234",
      branch: "w",
    )
    harness.store.replaceWorktrees([primary, short], forProject: harness.project.id)
    return short
  }

  private func renamedWorktree(onBranch branch: String, in harness: ModelHarness) -> Worktree {
    let worktree = harness.addPrimaryWorktree(branch: branch)
    harness.model.renameWorktree(worktree.id, to: "Auth")
    return worktree
  }

  @Test func aHeaderTooNarrowForAReadablePathDrawsNoneOfIt() throws {
    let harness = ModelHarness()
    let runs = try inkRuns(
      inHeaderOfWidth: 160,
      showing: harness.addPrimaryWorktree(),
      in: harness,
    )

    #expect(runs.count == 1, "the chevron alone")
  }

  @Test func aWideHeaderDrawsThePathBesideTheChevron() throws {
    let harness = ModelHarness()
    let runs = try inkRuns(
      inHeaderOfWidth: 1600,
      showing: harness.addPrimaryWorktree(),
      in: harness,
    )

    try #require(runs.count >= 2)
    #expect(runs.dropFirst().count { $0.count > runs[0].count * 5 } > 0, "a path past the chevron")
  }

  @Test func aPathShorterThanTheLeastAllowedShowsWholeWhereItFits() throws {
    let harness = ModelHarness()
    let worktree = worktreeAtAShortPath(in: harness)
    let wide = try inkRuns(inHeaderOfWidth: 1600, showing: worktree, in: harness)
    try #require(wide.count == 2, "chevron, path")
    let roomForThePathAndLittleMore = Double(wide[1].upperBound) + Self.headerEndAfterTheText

    let runs = try inkRuns(
      inHeaderOfWidth: roomForThePathAndLittleMore,
      showing: worktree,
      in: harness,
    )

    try #require(runs.count == 2)
    #expect(abs(runs[1].count - wide[1].count) <= Self.subpixelSlack)
  }

  @Test func aRenamedWorktreesBranchKeepsItsWholeNameBeforeThePathTakesRoom() throws {
    let harness = ModelHarness()
    let worktree = renamedWorktree(onBranch: "feature/long-branch-name", in: harness)
    let wide = try inkRuns(inHeaderOfWidth: 1600, showing: worktree, in: harness)
    try #require(wide.count >= 3, "chevron, branch, path")
    let roomForTheBranchAndNoPath = Double(wide[1].upperBound) + Self.headerEndAfterTheText

    let runs = try inkRuns(
      inHeaderOfWidth: roomForTheBranchAndNoPath,
      showing: worktree,
      in: harness,
    )

    try #require(runs.count == 2, "chevron, branch")
    #expect(abs(runs[1].count - wide[1].count) <= Self.subpixelSlack)
  }

  @Test func aRenamedWorktreesLongBranchGivesWayBeforeTheProjectsName() throws {
    let harness = ModelHarness()
    let worktree = renamedWorktree(
      onBranch: "feature/JIRA-1234-rework-token-refresh-and-session-expiry",
      in: harness,
    )
    let wide = try inkRuns(inHeaderOfWidth: 1600, showing: worktree, in: harness, of: .text)
    let projectEnd = try #require(wide.last?.upperBound)
    let roomForTheNamesAndAFewOfTheBranch = Double(projectEnd) + 200

    let narrow = try inkRuns(
      inHeaderOfWidth: roomForTheNamesAndAFewOfTheBranch,
      showing: worktree,
      in: harness,
      of: .text,
    )

    #expect(abs((narrow.last?.upperBound ?? 0) - projectEnd) <= Self.subpixelSlack)
  }
}
