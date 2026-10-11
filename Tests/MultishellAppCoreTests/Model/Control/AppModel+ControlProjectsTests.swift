import Foundation
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite @MainActor
struct AppModelControlProjectsTests {
  @Test func theListNamesEachProjectByItsIDBesideItsPath() async throws {
    let harness = Harness()

    let reply = try #require(await harness.messageSource.ask(.listProjects))

    let projects = try #require(reply.outputObject as? [[String: Any]])
    #expect(projects.compactMap { $0["id"] as? String } == [ControlID.project(harness.project.id)])
    #expect(projects.first?["path"] as? String == harness.project.id)
    #expect(projects.first?["worktreeCount"] as? Int == 2)
  }

  @Test func removingAProjectClosesItsShellsWithNoDialogButNotOverAWorkingAgent() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: tab.focusedSessionID)
    )
    let id = ControlID.project(harness.project.id)

    #expect(
      await harness.messageSource.ask(.removeProject(id: id, force: false))
        == .refused(.agentWorking)
    )
    #expect(harness.model.workspace.projects.count == 1)

    #expect(await harness.messageSource.ask(.removeProject(id: id, force: true)) == .done)
    #expect(harness.model.workspace.projects.isEmpty)
    #expect(harness.model.pendingProjectRemoval == nil)
    #expect(harness.engine.closed == [tab.focusedSessionID])
  }

  @Test func removingAProjectWhoseRemovalDialogIsUpTakesTheDialogDown() async throws {
    let harness = Harness()
    harness.model.requestProjectRemoval(harness.project, from: .workspace)
    let id = ControlID.project(harness.project.id)

    #expect(await harness.messageSource.ask(.removeProject(id: id, force: true)) == .done)
    #expect(harness.model.pendingProjectRemoval == nil)
  }

  @Test func addingAFolderInARepositoryAddsTheRepository() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let other = harness.root.appendingPathComponent("other", isDirectory: true)
    try await TestRepository.initialise(at: other, withFirstCommit: true, using: harness.git)
    let folder = other.appendingPathComponent("src", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    let reply = await harness.model.answer(.addProject(path: folder.path))

    #expect(
      reply.outputFields["id"] as? String
        == harness.model.workspace.projects.last.map { ControlID.project($0.id) }
    )
    #expect(harness.model.workspace.projects.count == 2)
    let added = try #require(harness.model.workspace.projects.last)
    #expect(added.path.resolvingSymlinksInPath() == other.resolvingSymlinksInPath())
  }

  @Test func addingAFolderInNoRepositoryAnswersWithTheAlertAndLeavesNoneStanding() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let plain = harness.root.appendingPathComponent("plain", isDirectory: true)
    try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)

    let reply = await harness.model.answer(.addProject(path: plain.path))

    guard case .alert(let title, _)? = reply.refusal else {
      Issue.record("not an alert: \(reply)")
      return
    }
    #expect(!title.isEmpty)
    #expect(harness.model.presentedError == nil)
    #expect(harness.model.workspace.projects.count == 1)
  }
}
