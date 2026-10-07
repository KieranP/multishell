import Foundation
import Testing

@testable import MultishellCore

@Suite
struct ProjectSettingsLayeringTests {
  @Test func theUsersValuesWinAndTheFileFillsWhatTheyLeftBlank() throws {
    let shared = try writtenAndReadBack(
      SharedProjectSettings(
        worktreeDirectory: "../trees", branchPrefix: "team/", defaultBranch: "develop",
        postCreateHook: "npm ci", iconGlyph: "hammer", iconTint: 4))
    let blank = ProjectSettings().layered(over: shared)
    #expect(blank.branchPrefix == "team/", "naming a branch writes nothing")
    #expect(blank.defaultBranch == "develop", "a repository may name the branch it merges into")
    #expect(blank.iconGlyph == "hammer" && blank.iconTint == 4)
    #expect(blank.postCreateHook == "", "hooks wait for trust")
    #expect(blank.worktreeDirectory == nil, "and so does where a checkout lands")

    var ownSettings = ProjectSettings(
      branchPrefix: "me/", defaultBranch: "trunk", postCreateHook: "make", iconTint: 1)
    ownSettings.trustDecisions = [
      TrustDecision(digest: try #require(shared.digest), isTrusted: true)
    ]
    let own = ownSettings.layered(over: shared)
    #expect(own.worktreeDirectory == "../trees", "left blank, so the file's")
    #expect(own.branchPrefix == "me/" && own.iconTint == 1)
    #expect(own.defaultBranch == "trunk", "the user's name stands over the file's")
    #expect(own.postCreateHook == "make", "the user's hook stands over the file's")

    #expect(
      ProjectSettings(branchPrefix: "me/").layered(over: nil)
        == ProjectSettings(branchPrefix: "me/"))
  }

  /// Unlike a hook this runs nothing the repository wrote, only the shell or agent the user
  /// chose, so it needs no trust decision.
  @Test func aRepositoryMaySayWhatItsWorktreesOpenAndTheUsersOwnAnswerWins() throws {
    let shared = try decodeJSON(
      SharedProjectSettings.self,
      #"{ "autoStartAgent": true, "autoStartAgentOnCreate": true, "opensTerminalOnSelect": false, "opensTerminalOnCreate": true }"#
    )
    #expect(shared.autoStartsAgent == true && shared.autoStartsAgentOnCreate == true)
    #expect(shared.opensTerminalOnSelect == false && shared.opensTerminalOnCreate == true)

    let blank = ProjectSettings().layered(over: shared)
    #expect(blank.autoStartsAgent == true && blank.autoStartsAgentOnCreate == true)
    #expect(blank.opensTerminalOnSelect == false && blank.opensTerminalOnCreate == true)

    let own = ProjectSettings(autoStartsAgent: false, opensTerminalOnSelect: true)
      .layered(over: shared)
    #expect(own.autoStartsAgent == false, "the user's off stands over the file's on")
    #expect(own.opensTerminalOnSelect == true)
    #expect(own.autoStartsAgentOnCreate == true, "left alone, so the file's")

    let exported = SharedProjectSettings(exporting: blank)
    #expect(exported.autoStartsAgentOnCreate == true && exported.opensTerminalOnSelect == false)
  }

  @Test func aGlyphNoBuildDrawsIsNotAChoiceAndDoesNotMaskTheRepositorys() throws {
    let shared = try decodeJSON(
      SharedProjectSettings.self, #"{ "iconGlyph": "server.rack", "iconTint": 4 }"#)

    let blank = ProjectSettings().layered(over: shared)
    #expect(blank.iconGlyph == "server.rack" && blank.iconTint == 4)

    let own = ProjectSettings(iconGlyph: "cylinder").layered(over: shared)
    #expect(own.iconGlyph == "cylinder", "the user's choice stands over the file's")

    let leftover = ProjectSettings(iconGlyph: "🚀").layered(over: shared)
    #expect(
      leftover.iconGlyph == "server.rack",
      "an emoji from a build that offered them is a gap, not a choice over the file")

    let fileEmoji = try decodeJSON(SharedProjectSettings.self, #"{ "iconGlyph": "🚀" }"#)
    #expect(ProjectSettings().layered(over: fileEmoji).iconGlyph == nil, "and neither way round")
  }

  @Test func theIconInForceIsAlwaysASymbolNameAndSurvivesARoundTrip() {
    let stored: [String?] = [
      nil, "", "   ", "folder", "hammer", "  hammer  ", "server.rack",
      "sparkle.magnifyingglass", "not.a.symbol", "🚀", " 🚀 ", "🚀 hammer",
    ]
    for own in stored {
      for file in stored {
        let settings = ProjectSettings(iconGlyph: own)
        for shared in [SharedProjectSettings(iconGlyph: file), nil] {
          let effective = settings.layered(over: shared)
          #expect(
            ProjectIcon.normalizedGlyph(effective.iconGlyph) == effective.iconGlyph,
            "own \(own ?? "nil"), file \(file ?? "nil"): not a symbol name")

          let exported = SharedProjectSettings(exporting: effective)
          #expect(
            ProjectSettings().layered(over: exported).iconGlyph == effective.iconGlyph,
            "own \(own ?? "nil"), file \(file ?? "nil"): changed by the round trip")
        }
      }
    }
  }

  @Test func aRepositoryMaySayWhatOrderItsWorktreesListInAndTheUsersOwnWins() throws {
    let shared = try decodeJSON(
      SharedProjectSettings.self,
      #"{ "worktreeSortOrder": "committedNewestFirst", "showsActiveWorktreesFirst": true }"#)
    #expect(shared.worktreeSortOrder == .committedNewestFirst)
    #expect(shared.showsActiveWorktreesFirst == true)

    let blank = ProjectSettings().layered(over: shared)
    #expect(blank.worktreeSortOrder == .committedNewestFirst, "the gap the user left")
    #expect(blank.showsActiveWorktreesFirst == true)

    let own = ProjectSettings(
      worktreeSortOrder: .alphabetical, showsActiveWorktreesFirst: false
    ).layered(over: shared)
    #expect(own.worktreeSortOrder == .alphabetical, "the user's choice stands over the file's")
    #expect(own.showsActiveWorktreesFirst == false)

    // What Export writes back out, so a round trip through the file keeps
    // the order the project is actually using.
    let exported = SharedProjectSettings(exporting: blank)
    #expect(exported.worktreeSortOrder == .committedNewestFirst)
    #expect(exported.showsActiveWorktreesFirst == true)
    let written = try decodeJSON(
      SharedProjectSettings.self,
      String(decoding: try JSONEncoder().encode(exported), as: UTF8.self))
    #expect(written == exported)
  }
}
