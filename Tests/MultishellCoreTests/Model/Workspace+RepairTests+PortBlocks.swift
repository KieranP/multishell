import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceRepairTests {
  @Test func aStateFileFromBeforePortBlocksGivesEachWorktreeOneOnLoad() throws {
    let other = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-b"),
      projectID: project.id,
      head: "b",
      branch: "b",
    )
    var workspace = Workspace()
    workspace.projects = [project]
    workspace.worktrees = [worktree, other]
    var json = try #require(
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(workspace)) as? [String: Any]
    )
    json["portBlocks"] = nil
    var loaded = try JSONDecoder().decode(
      Workspace.self,
      from: JSONSerialization.data(withJSONObject: json),
    )

    loaded.repair()

    #expect(loaded.port(of: worktree.id) == 3000)
    #expect(loaded.port(of: other.id) == 3010)
  }

  @Test func aBlockForAMissingWorktreeGoesAndAShareOrNegativeIsGivenAgain() {
    let other = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-b"),
      projectID: project.id,
      head: "b",
      branch: "b",
    )
    var workspace = Workspace()
    workspace.projects = [project]
    workspace.worktrees = [worktree, other]
    workspace.portBlocks = ["/repos/nowhere": 0, worktree.id: 2, other.id: 2]

    workspace.repair()

    #expect(workspace.portBlocks["/repos/nowhere"] == nil)
    #expect(Set(workspace.portBlocks.values) == [0, 2])

    workspace.portBlocks = [worktree.id: -1, other.id: 0]
    workspace.repair()

    #expect(workspace.portBlocks == [worktree.id: 1, other.id: 0])
  }

  @Test func aBareRepositorysBlockDoesNotCostAWorktreeSharingItsIndex() {
    let bare = Worktree(path: project.path, projectID: project.id, head: "", isBare: true)
    let linked = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-b"),
      projectID: project.id,
      head: "b",
      branch: "b",
    )
    var workspace = Workspace()
    workspace.projects = [project]
    workspace.worktrees = [bare, linked]
    workspace.portBlocks = [bare.id: 1, linked.id: 1]

    workspace.repair()

    #expect(workspace.portBlocks == [linked.id: 1])
  }

  @Test func anUnrepairedIndexNoSettingCouldFitHasNoPortRatherThanOverflowing() {
    var workspace = Workspace()
    workspace.projects = [project]
    workspace.worktrees = [worktree]
    workspace.portBlocks = [worktree.id: 1_000_000_000_000_000_000]

    #expect(workspace.port(of: worktree.id) == nil)
  }

  @Test func aBlockNoSettingCouldFitIsGivenAgainRatherThanOverflowing() {
    var workspace = Workspace()
    workspace.projects = [project]
    workspace.worktrees = [worktree]
    workspace.portBlocks = [worktree.id: 1_000_000_000_000_000_000]

    workspace.repair()

    #expect(workspace.port(of: worktree.id) == 3000)
  }
}
