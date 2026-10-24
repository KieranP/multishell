import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite(.serialized) @MainActor
struct AppModelPortBlocksTests {
  @Test func aCreatedWorktreesHooksGetItsPortAndItsRemovalFreesTheBlock() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let record = { (file: String) in
      "printf %s \"${MULTISHELL_PORT-unset}\" > \"$MULTISHELL_PROJECT_PATH/\(file)\""
    }
    harness.model.setSettings(
      ProjectSettings(
        postCreateHook: record("created.txt"),
        preDeleteHook: record("removing.txt"),
      ),
      for: harness.project,
    )
    harness.model.setPortBlockStart(41_000)

    let created = try await harness.createWorktree(onBranch: "ported")
    await harness.model.stageHandles.setupTask(of: created.id)?.value
    await harness.model.removeWorktree(created, deletesBranch: false, trashes: false)

    let recorded = try ["created", "removing"].map { name in
      try String(
        contentsOf: harness.project.path.appendingPathComponent("\(name).txt"),
        encoding: .utf8,
      )
    }
    #expect(recorded == ["41010", "41010"], "the main checkout holds 41000")
    #expect(harness.model.workspace.portBlocks[created.id] == nil)
    #expect(Set(harness.model.workspace.portBlocks.values) == [0])
  }

  @Test func theRefreshARemovalCausesKeepsItsRowHookAndBlockToItsEnd() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("gate")
    let written = harness.root.appendingPathComponent("post-delete.txt")
    harness.model.setSettings(
      ProjectSettings(
        postDeleteHook:
          "while [ ! -e '\(gate.path)' ]; do sleep 0.05; done; "
          + "printf %s \"$MULTISHELL_PORT\" > '\(written.path)'"
      ),
      for: harness.project,
    )
    let leaving = try await harness.createWorktree(onBranch: "leaving")
    let removal = Task {
      await harness.model.removeWorktree(leaving, deletesBranch: false, trashes: false)
    }
    try await waitUntil(
      { harness.model.worktreeOperations[leaving.id]?.stage == .postDeleteHook },
      seconds: 10,
    )

    await harness.model.refreshWorktrees(of: harness.project)
    #expect(harness.model.workspace.worktree(leaving.id) != nil, "its row, with Cancel, stays")
    let arriving = try await harness.createWorktree(onBranch: "arriving")
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    _ = await removal.value

    #expect(try String(contentsOf: written, encoding: .utf8) == "3010", "ran to its end")
    #expect(harness.model.workspace.port(of: arriving.id) == 3020, "3010 was still held")
    #expect(harness.model.workspace.worktree(leaving.id) == nil)
    #expect(harness.model.workspace.portBlocks[leaving.id] == nil, "freed once it ended")
  }

  @Test func removingTheProjectEndsAPostDeleteHookPastItsRecord() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("gate")
    let written = harness.root.appendingPathComponent("post-delete.txt")
    harness.model.setSettings(
      ProjectSettings(
        postDeleteHook:
          "while [ ! -e '\(gate.path)' ]; do sleep 0.05; done; echo ran > '\(written.path)'"
      ),
      for: harness.project,
    )
    let leaving = try await harness.createWorktree(onBranch: "leaving")
    let removal = Task {
      await harness.model.removeWorktree(leaving, deletesBranch: false, trashes: false)
    }
    try await waitUntil(
      { harness.model.worktreeOperations[leaving.id]?.stage == .postDeleteHook },
      seconds: 10,
    )
    await harness.model.refreshWorktrees(of: harness.project)

    harness.model.removeProject(harness.project)
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    _ = await removal.value

    #expect(!FileManager.default.fileExists(atPath: written.path))
  }

  @Test func aCreateAtAPathWhoseRemovalStillRunsIsRefused() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("gate")
    harness.model.setSettings(
      ProjectSettings(postDeleteHook: "while [ ! -e '\(gate.path)' ]; do sleep 0.05; done"),
      for: harness.project,
    )
    let leaving = try await harness.createWorktree(onBranch: "leaving")
    let removal = Task {
      await harness.model.removeWorktree(leaving, deletesBranch: false, trashes: false)
    }
    try await waitUntil(
      { harness.model.worktreeOperations[leaving.id]?.stage == .postDeleteHook },
      seconds: 10,
    )
    await harness.model.refreshWorktrees(of: harness.project)

    let again = await harness.model.createWorktree(
      branch: "leaving",
      basedOn: nil,
      createsBranch: false,
      in: harness.project,
    )
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    _ = await removal.value

    #expect(again == nil)
    #expect(harness.model.presentedError?.title == "A removal is still running there")
    #expect(harness.worktree(onBranch: "leaving") == nil)
  }

  @Test func aCreateThroughASymlinkToAPathWhoseRemovalStillRunsIsRefused() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let real = harness.root.appendingPathComponent("trees-real", isDirectory: true)
    let link = harness.root.appendingPathComponent("trees-link")
    try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
    let gate = harness.root.appendingPathComponent("gate")
    harness.model.setSettings(
      ProjectSettings(
        worktreeDirectory: link.path,
        postDeleteHook: "while [ ! -e '\(gate.path)' ]; do sleep 0.05; done",
      ),
      for: harness.project,
    )
    let leaving = try await harness.createWorktree(onBranch: "leaving")
    let removal = Task {
      await harness.model.removeWorktree(leaving, deletesBranch: false, trashes: false)
    }
    try await waitUntil(
      { harness.model.worktreeOperations[leaving.id]?.stage == .postDeleteHook },
      seconds: 10,
    )
    await harness.model.refreshWorktrees(of: harness.project)

    let again = await harness.model.createWorktree(
      branch: "leaving",
      basedOn: nil,
      createsBranch: false,
      in: harness.project,
    )
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    _ = await removal.value

    #expect(again == nil)
    #expect(harness.model.presentedError?.title == "A removal is still running there")
  }

  @Test func aCreateAtAPathWhoseRemovalIsInItsPreDeleteHookIsRefused() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("gate")
    harness.model.setSettings(
      ProjectSettings(preDeleteHook: "while [ ! -e '\(gate.path)' ]; do sleep 0.05; done"),
      for: harness.project,
    )
    let leaving = try await harness.createWorktree(onBranch: "leaving")
    let removal = Task {
      await harness.model.removeWorktree(leaving, deletesBranch: false, trashes: false)
    }
    try await waitUntil(
      { harness.model.worktreeOperations[leaving.id]?.stage == .preDeleteHook },
      seconds: 10,
    )

    let again = await harness.model.createWorktree(
      branch: "leaving",
      basedOn: nil,
      createsBranch: false,
      in: harness.project,
    )
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    _ = await removal.value

    #expect(again == nil)
    #expect(harness.model.presentedError?.title == "A removal is still running there")
  }

  @Test func aWorktreeRemovedOutsideTheAppDuringItsPreDeleteHookEndsThatRemoval() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("gate")
    harness.model.setSettings(
      ProjectSettings(preDeleteHook: "while [ ! -e '\(gate.path)' ]; do sleep 0.05; done"),
      for: harness.project,
    )
    let leaving = try await harness.createWorktree(onBranch: "leaving")
    let removal = Task {
      await harness.model.removeWorktree(leaving, deletesBranch: false, trashes: false)
    }
    try await waitUntil(
      { harness.model.worktreeOperations[leaving.id]?.stage == .preDeleteHook },
      seconds: 10,
    )

    try await harness.removeOutsideTheApp(leaving.path)
    await harness.model.refreshWorktrees(of: harness.project)

    #expect(harness.model.worktreeOperations[leaving.id] == nil)
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    _ = await removal.value
  }

  @Test func aWorktreeCreatedWithNoRoomLeftRaisesAnAlertNamingIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setPortBlockStart(65_520)

    let created = try await harness.createWorktree(onBranch: "crowded")

    #expect(harness.model.workspace.port(of: created.id) == nil)
    let alert = try #require(harness.model.presentedError)
    #expect(alert.title == "No port block for a worktree")
    #expect(
      alert.message.hasPrefix(
        "A port block would end past 65535, so MULTISHELL_PORT is unset in crowded."
      )
    )
  }

  @Test func aWorktreeCreatedWithNoRoomLeftLeavesAnAlertAlreadyUp() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setPortBlockStart(65_520)
    harness.model.presentedError = PresentedError(title: "Retry me", message: "")

    _ = try await harness.createWorktree(onBranch: "crowded")

    #expect(harness.model.presentedError?.title == "Retry me")
  }

  @Test func theCreateAlertBelongsToNoCommandLineRequest() {
    let harness = Harness()
    harness.model.setPortBlockStart(65_520)

    ControlRequestScope.$id.withValue(UUID()) {
      harness.model.alertNoPortBlock(for: harness.feature)
    }

    #expect(harness.model.presentedError?.title == "No port block for a worktree")
    #expect(harness.model.presentedError?.raisingRequestID == nil)
  }

  @Test func aSettingThatLeavesWorktreesWithoutPortsRaisesNoAlertAndTheCaptionNamesThem() {
    let harness = Harness()

    harness.model.setPortBlockStart(65_535)

    #expect(harness.model.presentedError == nil)
    let caption = harness.model.worktreesWithoutPortsCaption
    #expect(caption?.contains("main (\(harness.project.name))") == true)
    #expect(caption?.contains("feature (\(harness.project.name))") == true)
  }

  @Test func theCaptionGoesOnceEveryWorktreeHasAPortAgain() {
    let harness = Harness()
    harness.model.setPortBlockStart(65_520)
    #expect(harness.model.worktreesWithoutPortsCaption != nil)

    harness.model.setPortBlockStart(3000)

    #expect(harness.model.worktreesWithoutPortsCaption == nil)
  }

  @Test func aCommandLineWriteThatLeavesAWorktreeWithoutAPortSucceeds() async {
    let harness = Harness()

    let reply = await harness.messageSource.ask(
      .writeGlobalSetting(key: "portBlockStart", value: "65520")
    )

    #expect(reply == .done)
  }
}
