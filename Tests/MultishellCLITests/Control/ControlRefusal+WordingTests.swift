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
