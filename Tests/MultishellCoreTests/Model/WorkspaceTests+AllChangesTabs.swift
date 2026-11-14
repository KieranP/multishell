import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceTests {
  @Test func aStateFileWithoutAllChangesTabsOpensNone() throws {
    let workspace = try decodeJSON(Workspace.self, #"{ "projects": [] }"#)

    #expect(workspace.allChangesTabs.isEmpty)
  }

  @Test func anAllChangesTabIsReadBackFromItsOwnKey() throws {
    let workspace = try decodeJSON(
      Workspace.self,
      #"{ "allChangesTabs": [ { "id": "6B1F1E52-6C2A-4F3B-9D47-1A0B2C3D4E5F", "worktreeID": "/repos/demo" }, { "worktreeID": 7 } ] }"#,
    )

    #expect(
      workspace.allChangesTabs.map(\.worktreeID) == ["/repos/demo"],
      "a broken entry costs itself",
    )
  }
}
