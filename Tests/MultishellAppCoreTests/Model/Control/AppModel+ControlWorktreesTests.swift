import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelControlWorktreesTests {
  func order(
    _ branch: String,
    in harness: GitHarness,
    projectID: String? = nil,
    agentID: String? = nil,
    task: String? = nil,
  ) -> NewWorktreeOrder {
    NewWorktreeOrder(
      branch: branch,
      projectID: projectID ?? ControlID.project(harness.project.id),
      createsBranch: true,
      startPoint: nil,
      agentID: agentID,
      task: task,
    )
  }

  @Test func theListNamesEachWorktreeByItsIDUnderItsProjectsBesideItsPath() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let project = ControlID.project(harness.project.id)

    let reply = await harness.model.answer(.listWorktrees(project: project))

    let worktrees = try #require(reply.outputObject as? [[String: Any]])
    #expect(
      worktrees.compactMap { $0["id"] as? String }
        == harness.model.workspace.worktrees.map { ControlID.worktree($0.id) }
    )
    #expect(
      worktrees.compactMap { $0["path"] as? String } == harness.model.workspace.worktrees.map(\.id)
    )
    #expect(worktrees.first?["project"] as? String == project)
    #expect(worktrees.first?["isPrimary"] as? Bool == true)
  }

  @Test func selectingAWorktreeIsAClickOnItsRow() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.model.workspace.worktrees.first)

    #expect(await harness.model.answer(.selectWorktree(id: ControlID.worktree(main.id))) == .done)
    #expect(harness.model.workspace.selectedWorktreeID == main.id)
  }

  @Test func aRenameNamesTheRowAndNoNameHandsItBackToTheBranch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.model.workspace.worktrees.first)
    let id = ControlID.worktree(main.id)

    #expect(await harness.model.answer(.renameWorktree(id: id, name: "Trunk")) == .done)
    #expect(harness.model.displayName(of: main) == "Trunk")
    #expect(await harness.model.answer(.renameWorktree(id: id, name: nil)) == .done)
    #expect(harness.model.displayName(of: main) == main.branch)
  }

  @Test func aRenameOfAnIDNoWorktreeHasIsRefusedByThatID() async throws {
    let harness = Harness()

    #expect(
      await harness.messageSource.ask(.renameWorktree(id: "w-00000000", name: "x"))
        == .refused(.noWorktree(id: "w-00000000"))
    )
  }

  @Test func aRenameLeavesTheFieldOpenOnAnotherWorktree() async throws {
    let harness = Harness()
    harness.model.beginRenamingWorktree(harness.feature)
    let main = ControlID.worktree(harness.main.id)

    #expect(await harness.messageSource.ask(.renameWorktree(id: main, name: "Trunk")) == .done)
    #expect(harness.model.renamingWorktreeID == harness.feature.id)
  }

  @Test func autoRenameWhereItsMenuItemIsGreyedOutIsRefused() async {
    let harness = Harness()
    let id = ControlID.worktree(harness.feature.id)

    let reply = await harness.messageSource.ask(.autoRenameWorktree(id: id))

    #expect(reply == .refused(.autoRenameUnavailable(id: id)))
    #expect(harness.model.autoRenames.isEmpty)
  }
}
