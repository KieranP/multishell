import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite @MainActor
struct AppModelControlProjectsTests {
  @Test func theListNamesEachProjectByItsIDBesideItsPath() async throws {
    let harness = Harness()

    let reply = try #require(await harness.stateSource.ask(.listProjects))

    let projects = try #require(reply.outputObject as? [[String: Any]])
    #expect(projects.compactMap { $0["id"] as? String } == [ControlID.project(harness.project.id)])
    #expect(projects.first?["path"] as? String == harness.project.id)
    #expect(projects.first?["worktreeCount"] as? Int == 2)
  }

  @Test func removingAProjectClosesItsShellsWithNoDialogButNotOverAWorkingAgent() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.stateSource.send(SessionStateReport(state: .running, sessionID: tab.focusedSessionID))
    let id = ControlID.project(harness.project.id)

    #expect(
      await harness.stateSource.ask(.removeProject(id: id, force: false))
        == .refused(.agentWorking)
    )
    #expect(harness.model.workspace.projects.count == 1)

    #expect(await harness.stateSource.ask(.removeProject(id: id, force: true)) == .done)
    #expect(harness.model.workspace.projects.isEmpty)
    #expect(harness.model.pendingProjectRemoval == nil)
    #expect(harness.engine.closed == [tab.focusedSessionID])
  }

  @Test func removingAProjectWhoseRemovalDialogIsUpTakesTheDialogDown() async throws {
    let harness = Harness()
    harness.model.requestProjectRemoval(harness.project, from: .workspace)
    let id = ControlID.project(harness.project.id)

    #expect(await harness.stateSource.ask(.removeProject(id: id, force: true)) == .done)
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

  @Test func anAlertAlreadyStandingStaysWhenARequestRaisesItsOwn() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let standing = PresentedError(title: "Earlier", message: "Still up")
    harness.model.presentedError = standing
    let plain = harness.root.appendingPathComponent("plain", isDirectory: true)
    try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)

    _ = await harness.model.answer(.addProject(path: plain.path))

    #expect(harness.model.presentedError?.id == standing.id)
  }

  @Test func anAlertTheModelTookDownWhileARequestRanStaysDown() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (model, request, release) = try await addFolderHeldAtGitCheck(harness) { model in
      model.presentedError = PresentedError(title: "Git missing", message: "Found since")
    }

    model.presentedError = nil
    try release()
    _ = await request.value

    #expect(model.presentedError == nil)
  }

  @Test func anAlertAClickRaisedWhileARequestRanIsTheOneLeftStanding() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (model, request, release) = try await addFolderHeldAtGitCheck(harness) { model in
      model.presentedError = PresentedError(title: "Earlier", message: "Dismissed since")
    }

    model.answerPresentedError(try #require(model.presentedError), retrying: false)
    let clicked = PresentedError(title: "Clicked", message: "Raised meanwhile")
    model.presentedError = clicked
    try release()
    _ = await request.value

    #expect(model.presentedError?.id == clicked.id)
  }

  /// `release` lets the held repository check answer no, so the request
  /// raises its not-a-repository alert over whatever stands by then.
  private func addFolderHeldAtGitCheck(
    _ harness: GitHarness,
    before: (AppModel<FakeSurface>) -> Void,
  ) async throws -> (
    model: AppModel<FakeSurface>,
    request: Task<ControlReply, Never>,
    release: () throws -> Void
  ) {
    let plain = harness.root.appendingPathComponent("plain", isDirectory: true)
    try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)
    let gate = harness.root.appendingPathComponent("gate")
    let asked = harness.root.appendingPathComponent("asked")
    let model = try harness.modelWithRepositoryCheckHeld(in: plain, until: gate, asked: asked)
    before(model)
    let request = Task { await model.answer(.addProject(path: plain.path)) }
    try await waitUntil({ FileManager.default.fileExists(atPath: asked.path) }, seconds: 10)
    return (model, request, { try Data().write(to: gate) })
  }
}
