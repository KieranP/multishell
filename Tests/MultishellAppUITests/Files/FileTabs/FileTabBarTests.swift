import AppKit
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellGitKit

@Suite @MainActor
struct FileTabBarTests {
  /// Each of two groups in a 1100 pt window with both side panels open.
  private static let narrowGroupWidth = 283.0
  private static let wideGroupWidth = 900.0

  private func barOfferingBothSwitches(
    in harness: ModelHarness,
    theme: Theme = Theme.builtins[0],
    path: String = "src/middleware/auth.js",
  ) throws -> FileTabBar {
    let worktree = harness.addPrimaryWorktree()
    let tab = try #require(harness.store.openFileTab(path: path, in: worktree.id))
    harness.model.defaultBranchScans[harness.project.id] = .found(
      DefaultBranch(
        shortName: "main",
        nameWithoutRemote: "main",
        tip: "abc1234",
        fullName: "refs/heads/main",
      )
    )
    let rows = FileTabRows(
      lines: [
        DiffLine(kind: .removed, oldNumber: 1, newNumber: nil, text: "next()"),
        DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "verify(token)"),
      ],
      marksStaging: true,
    )
    let reading = FileTabReading(content: .text(rows), isFileGone: false)
    harness.model.fileTabReadings[tab.id] = reading
    try #require(harness.model.offersChangeScopeSwitch(for: tab))
    try #require(harness.model.offersLayoutSwitch(for: tab))
    return FileTabBar(model: harness.model, tab: tab, reading: reading, theme: theme)
  }

  private func selectedSegmentPixels(of bar: FileTabBar, width: Double) throws -> Int {
    let bitmap = try #require(
      OffscreenWindow.pixels(ofHosted: bar, size: CGSize(width: width, height: 30))
    )
    return MagentaTheme.pixelCount(in: bitmap)
  }

  @Test func aBarTooNarrowEvenWithItsSwitchesInTheMenuDrawsNothingPastItsGroup() throws {
    let harness = ModelHarness()
    let theme = try MagentaTheme.with([.fileTab: [.textSecondary]])
    let groupWidth = 150.0
    let bar = try barOfferingBothSwitches(in: harness, theme: theme)
      .frame(width: groupWidth)
      .frame(width: groupWidth * 3, alignment: .leading)

    let bitmap = try #require(
      OffscreenWindow.pixels(ofHosted: bar, size: CGSize(width: groupWidth * 3, height: 30))
    )
    let pastTheGroup = Int(groupWidth) * bitmap.pixelsWide / Int(groupWidth * 3)

    #expect(MagentaTheme.pixelCount(in: bitmap, fromX: pastTheGroup) == 0)
  }

  @Test func inANarrowGroupNeitherSwitchIsDrawnOnTheBar() throws {
    let harness = ModelHarness()
    let theme = try MagentaTheme.with([.fileTab: [.selectionBackground]])
    let bar = try barOfferingBothSwitches(in: harness, theme: theme)

    #expect(try selectedSegmentPixels(of: bar, width: Self.narrowGroupWidth) == 0)
  }

  @Test func inAWideGroupBothSwitchesAreDrawnOnTheBar() throws {
    let harness = ModelHarness()
    let theme = try MagentaTheme.with([.fileTab: [.selectionBackground]])
    let bar = try barOfferingBothSwitches(in: harness, theme: theme)

    #expect(try selectedSegmentPixels(of: bar, width: Self.wideGroupWidth) > 100)
  }

  @Test func aDeepFolderGivesWayRatherThanMovingTheSwitchesIntoTheMenu() throws {
    let harness = ModelHarness()
    let theme = try MagentaTheme.with([.fileTab: [.selectionBackground]])
    let deepPath =
      Array(repeating: "packages/server/src/middleware", count: 4)
      .joined(separator: "/") + "/auth.js"
    let bar = try barOfferingBothSwitches(in: harness, theme: theme, path: deepPath)

    #expect(try selectedSegmentPixels(of: bar, width: 600) > 100)
  }

  @Test func aFolderSqueezedBesideTheSwitchesDrawsNoneOfIt() throws {
    let harness = ModelHarness()
    let theme = try MagentaTheme.with([.fileTab: [.textTertiary, .selectionBackground]])
    let bar = try barOfferingBothSwitches(in: harness, theme: theme)
    let widthLeavingTheFolderOneMark = 465.0

    let bitmap = try #require(
      OffscreenWindow.pixels(
        ofHosted: bar,
        size: CGSize(width: widthLeavingTheFolderOneMark, height: 30),
      )
    )
    let scale = bitmap.pixelsWide / Int(widthLeavingTheFolderOneMark)

    #expect(MagentaTheme.pixelCount(in: bitmap, fromX: scale * 200) > 100, "the switches")
    #expect(MagentaTheme.pixelCount(in: bitmap, columns: 0..<(scale * 110)) == 0)
  }

  @Test func aNameWhoseFolderGaveWayStartsWhereARootFilesNameDoes() throws {
    let theme = try MagentaTheme.with([.fileTab: [.text]])
    let widthLeavingTheFolderNoRoom = 465.0
    func nameStart(path: String) throws -> Int? {
      let bar = try barOfferingBothSwitches(in: ModelHarness(), theme: theme, path: path)
      let bitmap = try #require(
        OffscreenWindow.pixels(
          ofHosted: bar,
          size: CGSize(width: widthLeavingTheFolderNoRoom, height: 30),
        )
      )
      return MagentaTheme.inkedColumns(in: bitmap).first
    }

    let rootFile = try #require(try nameStart(path: "auth.js"))
    let folderGaveWay = try #require(try nameStart(path: "src/middleware/auth.js"))

    #expect(folderGaveWay == rootFile)
  }
}
