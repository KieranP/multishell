import Foundation
import Testing

@testable import MultishellCore

struct KeyedDecodingContainerDefaultsTests {
  /// `decode(_:forKey:or:)` fills an absent key and still fails on a wrong
  /// type, which is what moves a state file aside as `.broken.json`.
  @Test func theStrictReadDefaultsWhatIsAbsentAndFailsOnWhatIsWrong() throws {
    #expect(try decodeJSON(Workspace.self, "{}").customShellPath == "")
    #expect(
      try decodeJSON(Workspace.self, #"{ "customShellPath": "/bin/fish" }"#)
        .customShellPath == "/bin/fish")
    #expect(throws: (any Error).self) {
      try decodeJSON(Workspace.self, #"{ "customShellPath": 7 }"#)
    }
  }

  /// A `decodeTolerantly` read takes the default for a value this build
  /// cannot read, and the rest of the file loads around it.
  @Test func theTolerantReadKeepsTheRestOfTheFile() throws {
    let order = try decodeJSON(
      Workspace.self, #"{ "worktreeSortOrder": 12, "customShellPath": "/bin/fish" }"#)
    #expect(order.worktreeSortOrder == WorktreeSortOrder.default)
    #expect(order.customShellPath == "/bin/fish")

    // The optional form, where absent is itself the answer.
    #expect(
      try decodeJSON(ProjectSettings.self, #"{ "worktreeSortOrder": 12 }"#)
        .worktreeSortOrder == nil)
  }
}
