import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

extension AppModelControlWorktreesTests {
  @Test func aNewWorktreeIsMadeAsTheSheetMakesOneAndAnswersItsIDAndBranch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    let reply = await harness.model.answer(.newWorktree(order("feat/cli", in: harness)))

    let created = try #require(harness.worktree(onBranch: "feat/cli"))
    #expect(reply.outputFields["id"] as? String == ControlID.worktree(created.id))
    #expect(reply.outputFields["branch"] as? String == "feat/cli")
    #expect(harness.model.workspace.selectedWorktreeID == created.id)
    #expect(FileManager.default.fileExists(atPath: created.path.path))
  }

  @Test func aBranchNameGitWouldRefuseIsRefusedBeforeGitRuns() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    let reply = await harness.model.answer(.newWorktree(order("bad..name", in: harness)))

    #expect(reply == .refused(.invalidBranchName("bad..name")))
    #expect(harness.model.workspace.worktrees(of: harness.project.id).count == 1)
  }

  @Test func aBranchThePrefixMakesInvalidIsRefusedWithAnAlertNamingThePrefixedBranch() async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(ProjectSettings(branchPrefix: "bad.."), for: harness.project)

    let reply = await harness.model.answer(.newWorktree(order("x", in: harness)))

    guard case .alert(let title, let message)? = reply.refusal else {
      Issue.record("not an alert: \(reply)")
      return
    }
    #expect((title + message).contains("bad..x"), "\(title) \(message)")
    #expect(harness.model.presentedError == nil)
    #expect(harness.model.workspace.worktrees(of: harness.project.id).count == 1)
  }

  @Test func aTaskWithNoAgentNamedOrPreferredIsRefused() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    let reply = await harness.model.answer(
      .newWorktree(order("feat/x", in: harness, task: "fix it"))
    )

    #expect(reply == .refused(.noAgentChosen))
    #expect(harness.worktree(onBranch: "feat/x") == nil)
  }

  @Test func aTaskStartsTheNamedAgentOnItInTheFirstTab() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    _ = await harness.model.answer(
      .newWorktree(order("feat/y", in: harness, agentID: "claude", task: "fix it"))
    )

    let created = try #require(harness.worktree(onBranch: "feat/y"))
    let tab = try #require(harness.model.workspace.activeTab(in: created.id))
    #expect(harness.model.workspace.session(tab.focusedSessionID)?.agentID == "claude")
    #expect(harness.engine.opened.last?.command?.last?.contains("fix it") == true)
  }

  @Test func anIDNoProjectHasIsRefusedByThatID() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let elsewhere = order("feat/z", in: harness, projectID: "p-00000000")

    #expect(
      await harness.model.answer(.newWorktree(elsewhere)) == .refused(.noProject(id: "p-00000000"))
    )
  }

  @Test func aWorktreeForAnAgentTheCatalogueLacksIsRefusedAndNotCreated() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let before = harness.model.workspace.worktrees.count

    let reply = await harness.model.answer(
      .newWorktree(order("feat/bogus", in: harness, agentID: "bogus"))
    )

    #expect(reply == .refused(.noAgent(id: "bogus")))
    #expect(harness.model.workspace.worktrees.count == before)
  }

  @Test func anAlertAnotherRaisesDuringACreateThatSucceedsIsLeftUpAndOneDismissedStaysDown()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let started = harness.root.appendingPathComponent("started")
    let gate = harness.root.appendingPathComponent("gate")
    harness.model.setSettings(
      ProjectSettings(
        preCreateHook: """
          touch "\(started.path)"
          while [ ! -e "\(gate.path)" ] && [ -d "\(harness.root.path)" ]; do sleep 0.05; done
          """
      ),
      for: harness.project,
    )
    let dismissed = PresentedError(title: "Earlier", message: "Read and dismissed")
    harness.model.presentedError = dismissed

    let create = Task { await harness.model.answer(.newWorktree(order("feat/slow", in: harness))) }
    try await waitUntil({ FileManager.default.fileExists(atPath: started.path) }, seconds: 15)
    harness.model.answerPresentedError(dismissed, retrying: false)
    let other = PresentedError(title: "Elsewhere", message: "Not the create's")
    harness.model.presentedError = other
    let stillCreatingWhenTheAlertsChanged = harness.worktree(onBranch: "feat/slow") == nil
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    let reply = await create.value

    #expect(stillCreatingWhenTheAlertsChanged)
    #expect(reply.refusal == nil, "\(reply)")
    #expect(harness.model.presentedError?.id == other.id)
    let created = try #require(harness.worktree(onBranch: "feat/slow"))
    await harness.model.stageHandles.setupTask(of: created.id)?.value
  }

  @Test func aCreateWhoseRequestIsCancelledStopsItsPreCreateHook() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let started = harness.root.appendingPathComponent("started")
    harness.model.setSettings(
      ProjectSettings(
        preCreateHook: """
          touch "\(started.path)"
          while [ -d "\(harness.root.path)" ]; do sleep 0.05; done
          """
      ),
      for: harness.project,
    )
    let finished = AtomicFlag()

    let create = Task {
      let reply = await harness.model.answer(.newWorktree(order("feat/stopped", in: harness)))
      finished.raise()
      return reply
    }
    try await waitUntil({ FileManager.default.fileExists(atPath: started.path) }, seconds: 15)
    create.cancel()
    try await waitUntil({ finished.raised }, seconds: 10)

    try #require(finished.raised)
    #expect(await create.value == .refused(.worktreeNotCreated))
    #expect(harness.worktree(onBranch: "feat/stopped") == nil)
    #expect(harness.model.presentedError == nil)
  }

  @Test func aCreateFromTheCommandLineLeavesTheSheetsCancelToTheSheetsCreate() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let marks = harness.root.appendingPathComponent("marks", isDirectory: true)
    try FileManager.default.createDirectory(at: marks, withIntermediateDirectories: true)
    harness.model.setSettings(
      ProjectSettings(preCreateHook: "touch \"\(marks.path)/$$\"; sleep 2"),
      for: harness.project,
    )
    let started = { (try? FileManager.default.contentsOfDirectory(atPath: marks.path).count) ?? 0 }

    let sheet = Task {
      await harness.model.createWorktree(
        branch: "feat/sheet",
        basedOn: nil,
        createsBranch: true,
        in: harness.project,
      )
    }
    try await waitUntil({ started() == 1 }, seconds: 15)
    let request = Task { await harness.model.answer(.newWorktree(order("feat/cli", in: harness))) }
    try await waitUntil({ started() == 2 }, seconds: 15)
    harness.model.cancelWorktreeCreation()

    #expect(await sheet.value == nil)
    #expect(await request.value.refusal == nil)
    #expect(harness.worktree(onBranch: "feat/cli") != nil)
    if let created = harness.worktree(onBranch: "feat/cli") {
      await harness.model.stageHandles.setupTask(of: created.id)?.value
    }
  }
}
