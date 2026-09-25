import Foundation
import Testing

@testable import MultishellCore

/// A broken element costs that element, not the file. One unknown pane kind
/// used to move the whole state aside and the sidebar came up empty.
@Suite
struct LossyArrayTests {
  private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
  }

  private func tabJSON(root: String) -> String {
    let session = UUID().uuidString
    return #"""
      { "id": "\#(UUID().uuidString)", "worktreeID": "/repos/demo",
        "root": \#(root), "focusedSessionID": "\#(session)" }
      """#
  }

  @Test func aTabWithAPaneKindFromANewerBuildIsDroppedAndTheProjectsKept() throws {
    let good = tabJSON(root: #"{ "terminal": { "_0": "\#(UUID().uuidString)" } }"#)
    let newer = tabJSON(root: #"{ "tabs": { "children": [] } }"#)
    let workspace = try decode(
      Workspace.self,
      #"""
      { "projects": [ { "path": "file:///repos/demo/" } ],
        "tabs": [ \#(good), \#(newer) ] }
      """#)

    #expect(workspace.projects.map(\.name) == ["demo"])
    #expect(workspace.tabs.count == 1)
  }

  @Test func badElementsOfEveryShapeAreSkippedWithoutStalling() throws {
    // A scalar, an object missing required keys, an invalid UUID, then a
    // sound element: the decoder must step past each bad one and finish.
    let sound = tabJSON(root: #"{ "terminal": { "_0": "\#(UUID().uuidString)" } }"#)
    let workspace = try decode(
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
    let workspace = try decode(
      Workspace.self,
      #"{ "projects": [ { "path": "file:///repos/demo/" } ], "tabs": { "oops": 1 }, "sessions": 3 }"#
    )
    #expect(workspace.projects.count == 1)
    #expect(workspace.tabs.isEmpty && workspace.sessions.isEmpty)
  }

  @Test func aBrokenProjectStillFailsTheFileSoTheBackupIsKept() {
    #expect(throws: DecodingError.self) {
      try decode(Workspace.self, #"{ "projects": [ { "isExpanded": true } ] }"#)
    }
  }

  @Test func soundCollectionsDecodeExactlyAsBefore() throws {
    var workspace = Workspace()
    let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
    let worktree = Worktree(path: project.path, projectID: project.id, head: "a", branch: "main")
    let session = TerminalSession(
      worktreeID: worktree.id, workingDirectory: worktree.path, title: "sh")
    var group = TabGroup(worktreeID: worktree.id)
    let tab = TerminalTab(worktreeID: worktree.id, groupID: group.id, session: session.id)
    group.activeTabID = tab.id
    workspace.projects = [project]
    workspace.worktrees = [worktree]
    workspace.sessions = [session]
    workspace.tabs = [tab]
    workspace.tabGroups = [group]
    workspace.focusedGroupByWorktree = [worktree.id: group.id]

    let json = try JSONEncoder().encode(workspace)
    #expect(try JSONDecoder().decode(Workspace.self, from: json) == workspace)
  }
}
