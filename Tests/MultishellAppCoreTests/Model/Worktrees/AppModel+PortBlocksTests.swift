import Foundation
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
}
