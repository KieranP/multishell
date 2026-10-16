import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelControlWorktreeDescriptionTests {
  @Test func aWorktreeIsShownWithItsGitStatusReadAfresh() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.model.workspace.worktrees.first)
    try harness.dirty(main)

    let reply = await harness.model.answer(.describeWorktree(id: ControlID.worktree(main.id)))

    #expect(reply.outputFields["id"] as? String == ControlID.worktree(main.id))
    #expect(reply.outputFields["path"] as? String == main.id)
    #expect(reply.outputFields["merge"] is String)
    let status = try #require(reply.outputFields["status"] as? [String: Any])
    #expect(status["changedFiles"] as? Int == 1)
    #expect(reply.outputFields["isStatusFresh"] as? Bool == true)
    #expect(reply.outputFields["operation"] == nil)
  }

  @Test func aWorktreeShownCountsEachFileInANewFolder() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.model.workspace.worktrees.first)
    let folder = main.path.appending(path: "new", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for name in ["a", "b", "c"] {
      try "x\n".write(to: folder.appending(path: name), atomically: true, encoding: .utf8)
    }

    let reply = await harness.model.answer(.describeWorktree(id: ControlID.worktree(main.id)))

    let status = try #require(reply.outputFields["status"] as? [String: Any])
    #expect(status["changedFiles"] as? Int == 3)
  }

  @Test func aWorktreeRemovedWhileItsGitIsReadIsRefusedAsGone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("gate")
    let model = try harness.modelWithStatusHeld(until: gate, answering: "main")
    let main = try #require(model.workspace.worktrees.first)
    let id = ControlID.worktree(main.id)

    let describe = Task { await model.answer(.describeWorktree(id: id)) }
    try await waitUntil({ harness.statusRunCount() > 0 }, seconds: 10)
    model.removeProject(harness.project)
    FileManager.default.createFile(atPath: gate.path, contents: nil)

    #expect(await describe.value == .refused(.noWorktree(id: id)))
  }
}
