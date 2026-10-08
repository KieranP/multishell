import Foundation
import Testing

@testable import MultishellCore

/// A broken element costs that element, not the file. One unknown pane kind
/// used to move the whole state aside and the sidebar came up empty.
@Suite
struct LossyArrayTests {
  @Test func aTabWithAPaneKindFromANewerBuildIsDroppedAndTheProjectsKept() throws {
    let good = tabJSON(root: #"{ "terminal": { "_0": "\#(UUID().uuidString)" } }"#)
    let newer = tabJSON(root: #"{ "tabs": { "children": [] } }"#)
    let workspace = try decodeJSON(
      Workspace.self,
      #"""
      { "projects": [ { "path": "file:///repos/demo/" } ],
        "tabs": [ \#(good), \#(newer) ] }
      """#)

    #expect(workspace.projects.map(\.name) == ["demo"])
    #expect(workspace.tabs.count == 1)
  }

  @Test func badElementsOfEveryShapeAreSkippedWithoutStalling() throws {
    let sound = tabJSON(root: #"{ "terminal": { "_0": "\#(UUID().uuidString)" } }"#)
    let workspace = try decodeJSON(
      Workspace.self,
      #"""
      { "tabs": [ 7, "text", null, [1, 2], { }, { "id": "nope" }, \#(sound) ],
        "sessions": [ 1, { "id": "\#(UUID().uuidString)", "worktreeID": "/w",
                           "workingDirectory": "file:///w/", "title": "sh" } ],
        "worktrees": [ { "projectID": "/p" }, { "path": "file:///w/", "projectID": "/p" } ] }
      """#)

    #expect(workspace.tabs.count == 1)
    #expect(workspace.sessions.count == 1)
    #expect(workspace.worktrees.count == 1)
  }

  @Test func aCollectionThatIsNotAnArrayReadsAsEmpty() throws {
    let workspace = try decodeJSON(
      Workspace.self,
      #"{ "projects": [ { "path": "file:///repos/demo/" } ], "tabs": { "oops": 1 }, "sessions": 3 }"#
    )
    #expect(workspace.projects.count == 1)
    #expect(workspace.tabs.isEmpty && workspace.sessions.isEmpty)
  }

  @Test func aBrokenProjectStillFailsTheWholeFile() {
    #expect(throws: DecodingError.self) {
      try decodeJSON(Workspace.self, #"{ "projects": [ { "isExpanded": true } ] }"#)
    }
  }

  @Test func aConsistentWorkspaceRoundTripsUnchanged() throws {
    let (workspace, _) = consistentWorkspace()

    let json = try JSONEncoder().encode(workspace)
    #expect(try JSONDecoder().decode(Workspace.self, from: json) == workspace)
  }
}
