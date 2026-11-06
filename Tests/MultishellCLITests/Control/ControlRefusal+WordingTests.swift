import Foundation
import TestScratch
import Testing

@testable import MultishellCLI
@testable import MultishellCore
@testable import MultishellProcess

@Suite
struct ControlRefusalWordingTests {
  @Test func aRefusedValueIsQuotedSoAnEmptyOneStillShows() {
    #expect(
      ControlRefusal.invalidValue(key: "themeID", value: "").wording
        == #"themeID takes no value """#
    )
  }

  @Test func aMissingServicePageNamesWhatTheWorktreeLacks() {
    #expect(
      ControlRefusal.noServicePage(.ciRuns, id: "w-89abcdef").wording
        == "worktree w-89abcdef has no CI run to show"
    )
    #expect(
      ControlRefusal.noServicePage(.pullRequest, id: "w-89abcdef").wording
        == "worktree w-89abcdef has no pull request to show"
    )
  }

  @Test func aProjectWithNoHiddenWorktreeSaysHowToHideOne() {
    #expect(
      ControlRefusal.noHiddenWorktrees(id: "p-0123abcd").wording
        == "project p-0123abcd has no hidden worktrees; "
        + "`multishell worktrees hide WORKTREE_ID` hides one"
    )
  }

  @Test func aFileTabRefusedSaysOnlyATerminalTabTakesIt() {
    let id = UUID()
    #expect(
      ControlRefusal.tabShowsAFile(id: id).wording
        == "tab \(id) shows a file; only a terminal tab takes that"
    )
  }

  @Test func aCoveredWindowSaysToBringItForward() {
    #expect(
      ControlRefusal.windowCovered.wording
        == "the main window is covered or on another Space; bring it forward"
    )
  }

  @Test func aScopeTheSwitcherHasNoneOfListsThoseItHas() {
    #expect(
      ControlRefusal.noSwitcherScope(name: "file", scopes: ["all", "files"]).wording
        == "the quick switcher has no scope file; its scopes are all, files"
    )
  }

  @Test func aMinimizedWindowSaysToBringItBackFromTheDock() {
    #expect(
      ControlRefusal.windowMinimized.wording
        == "the main window is minimized; bring it back from the Dock"
    )
  }

  @Test func aNoticeTabSaysWhyItHasNoText() {
    let id = UUID()
    #expect(
      ControlRefusal.fileTabShowsNotice(id: id).wording
        == "tab \(id) shows a notice, its file too large, binary, missing or unreadable"
    )
  }

  @Test func anImageTabSaysItHasNoLines() {
    let id = UUID()
    #expect(
      ControlRefusal.fileTabShowsImage(id: id).wording
        == "tab \(id) shows an image, which has no lines to step or find"
    )
  }

  @Test func aWidthOutOfRangeSaysTheRange() {
    #expect(
      ControlRefusal.widthOutOfRange(minimum: 200, maximum: 560).wording
        == "the width takes 200 to 560 points"
    )
  }

  @Test func eachCommandARefusalPointsToIsOneTheHelperParses() async throws {
    let app = try ControlListener(reply: .output("{}"))
    defer { app.stop() }
    let pane = UUID()
    let refusals: [ControlRefusal] = [
      .debugToolsOff, .noFindBar(id: pane), .noFindText(id: pane), .noKey(name: "f13"),
      .noMenuItem(path: "x"),
      .noPane(id: pane), .noProject(id: "p-00000000"), .noSetting(key: "x"), .noTab(id: pane),
      .noWorktree(id: "w-00000000"), .paneNotLive(id: pane), .windowInFullScreen,
      .worktreeNotRemovable(id: "w-00000000"), .filesPanelListsNoFiles,
      .noFilesFolder(path: "src"), .noSplit(id: pane, path: [1]), .tabNotShown(id: pane),
      .noHiddenWorktrees(id: "p-00000000"),
    ]
    let placeholders = ["PROJECT_ID": "p-0123abcd", "WORKTREE_ID": "w-89abcdef", "TEXT": "x"]

    for refusal in refusals {
      let quoted = refusal.wording.split(separator: "`", omittingEmptySubsequences: false)
        .enumerated().filter { !$0.offset.isMultiple(of: 2) }.map(\.element)
      #expect(!quoted.isEmpty, "\(refusal) names no command")
      for command in quoted {
        let words = command.split(separator: " ").map(String.init)
        #expect(words.first == "multishell", "\(command)")
        let arguments = words.dropFirst().map { placeholders[$0] ?? $0 }
        let output = try await HelperBinary.run(arguments, environment: app.environment)
        #expect(output.succeeded, "\(command): \(output.standardError)")
      }
    }
  }
}
