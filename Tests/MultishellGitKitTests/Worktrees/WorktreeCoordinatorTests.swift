import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellGitKit

/// End-to-end against a real repository in a temporary directory.
@Suite(.serialized)
struct WorktreeCoordinatorTests {
  @Test func createsAWorktreeWhereTheSettingsSayAndRunsTheHook() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    var project = repo.project
    project.settings = ProjectSettings(postCreateHook: "echo created > hook.txt")
    let settings = WorktreeSettings(worktreeDirectory: "../trees", branchPrefix: "kieran/")

    let coordinator = repo.coordinator
    let path = try await coordinator.create(branch: "tabs", in: project, settings: settings)

    #expect(path.lastPathComponent == "kieran-tabs")
    #expect(path.deletingLastPathComponent().lastPathComponent == "trees")
    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("hook.txt").path))

    let worktrees = try await coordinator.git.list(project)
    #expect(worktrees.count == 2)
    #expect(worktrees.contains { $0.branch == "kieran/tabs" })
  }

  @Test func removesAWorktreeAndRunsTheDeleteHook() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    var project = repo.project
    project.settings = ProjectSettings(postDeleteHook: "echo gone > deleted.txt")
    let settings = WorktreeSettings(worktreeDirectory: "../trees")

    let coordinator = repo.coordinator
    try await coordinator.create(branch: "scratch", in: project, settings: settings)

    let worktree = try await coordinator.git.list(project).first { $0.branch == "scratch" }
    try await coordinator.remove(#require(worktree), in: project)

    #expect(try await coordinator.git.list(project).count == 1)
    #expect(
      FileManager.default.fileExists(
        atPath: project.path.appendingPathComponent("deleted.txt").path))
  }

  @Test func aFailingHookLeavesTheWorktreeInPlace() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    var project = repo.project
    project.settings = ProjectSettings(postCreateHook: "exit 3")
    let settings = WorktreeSettings(worktreeDirectory: "../trees")

    let coordinator = repo.coordinator
    await #expect(throws: HookFailure.self) {
      try await coordinator.create(branch: "doomed", in: project, settings: settings)
    }
    #expect(try await coordinator.git.list(project).contains { $0.branch == "doomed" })
  }

  @Test func aFailingPreCreateHookLeavesNoWorktreeAndNoBranch() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(preCreateHook: "echo refused >&2\nexit 7")

    await #expect(throws: HookFailure.self) {
      try await repo.coordinator.create(branch: "refused", in: project, settings: repo.trees)
    }

    #expect(try await repo.coordinator.git.list(project).count == 1)
    #expect(try await repo.branches() == ["main"], "git was never asked")
    #expect(
      !FileManager.default.fileExists(
        atPath: repo.trees.worktreePath(forBranch: "refused", in: project).path))
  }

  @Test func aPreCreateHookRunsInTheRepositoryWithThePlannedPath() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(
      preCreateHook: "pwd > pre.txt\nprintf '%s' \"$MULTISHELL_WORKTREE_PATH\" > planned.txt")

    let path = try await repo.coordinator.create(
      branch: "planned", in: project, settings: repo.trees)

    let ran = try String(
      contentsOf: project.path.appendingPathComponent("pre.txt"), encoding: .utf8)
    #expect(
      ran.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("/demo"),
      "ran in the repository, not the planned worktree: \(ran)")
    let planned = try String(
      contentsOf: project.path.appendingPathComponent("planned.txt"), encoding: .utf8)
    #expect(planned == path.path, "the path the worktree is about to get")
  }

  @Test func aFailingPreDeleteHookLeavesTheWorktree() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(preDeleteHook: "exit 1")
    let path = try await repo.coordinator.create(branch: "kept", in: project, settings: repo.trees)
    let worktree = try #require(
      try await repo.coordinator.git.list(project).first { $0.branch == "kept" })

    await #expect(throws: HookFailure.self) {
      try await repo.coordinator.remove(worktree, in: project)
    }

    #expect(FileManager.default.fileExists(atPath: path.path))
    #expect(try await repo.coordinator.git.list(project).count == 2)
  }

  @Test func aPreDeleteHookRunsInTheWorktreeBeforeItGoes() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(
      preDeleteHook: "pwd > \"$MULTISHELL_PROJECT_PATH/where.txt\"")
    let path = try await repo.coordinator.create(
      branch: "leaving", in: project, settings: repo.trees)
    let worktree = try #require(
      try await repo.coordinator.git.list(project).first { $0.branch == "leaving" })

    try await repo.coordinator.remove(worktree, in: project)

    let ran = try String(
      contentsOf: project.path.appendingPathComponent("where.txt"), encoding: .utf8)
    // The shell may print the physical `/private/var` form of the temp
    // directory; Foundation leaves that prefix alone.
    func plain(_ text: String) -> String {
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.hasPrefix("/private/") ? String(trimmed.dropFirst("/private".count)) : trimmed
    }
    #expect(plain(ran) == plain(path.path))
    #expect(!FileManager.default.fileExists(atPath: path.path))
  }

  @Test func aPreDeleteHookRunsInTheRepositoryWhenTheDirectoryIsAlreadyGone() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(preDeleteHook: "pwd > where.txt")
    let path = try await repo.coordinator.create(
      branch: "vanished", in: project, settings: repo.trees)
    let worktree = try #require(
      try await repo.coordinator.git.list(project).first { $0.branch == "vanished" })
    try FileManager.default.removeItem(at: path)

    try await repo.coordinator.remove(worktree, in: project)

    let ran = try String(
      contentsOf: project.path.appendingPathComponent("where.txt"), encoding: .utf8)
    func plain(_ text: String) -> String {
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.hasPrefix("/private/") ? String(trimmed.dropFirst("/private".count)) : trimmed
    }
    #expect(plain(ran) == plain(project.path.path))
    #expect(try await repo.coordinator.git.list(project).count == 1)
  }

  @Test func aMultiLineHookRunsItsLinesInOrderAndStopsAtAFailure() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(
      postCreateHook: "echo one >> order.txt\necho two >> order.txt\nfalse\necho three >> order.txt"
    )

    await #expect(throws: HookFailure.self) {
      try await repo.coordinator.create(branch: "lines", in: project, settings: repo.trees)
    }

    let path = repo.trees.worktreePath(forBranch: "lines", in: project)
    let order = try String(contentsOf: path.appendingPathComponent("order.txt"), encoding: .utf8)
    #expect(order == "one\ntwo\n", "in order, in the worktree, and nothing after the failure")
  }

  @Test func hooksRunThroughTheShellTheProjectChose() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let shells = try Scratch.directory("shells")
    defer { Scratch.remove(shells) }
    var project = repo.project
    project.settings = ProjectSettings(postCreateHook: "true")

    for name in ["zsh", "bash"] {
      let shell = try Scratch.script(
        "printf %s \(name) > shell.txt", at: shells.appendingPathComponent(name))
      let created = try await repo.coordinator.create(
        branch: name, in: project, settings: repo.trees, shellPath: shell.path)
      #expect(
        try String(contentsOf: created.appendingPathComponent("shell.txt"), encoding: .utf8)
          == name)
    }
  }

  @Test func removingCanDeleteTheBranchAfterThePostHookHasSeenIt() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(
      postDeleteHook: "git rev-parse --verify \"$MULTISHELL_BRANCH\" > hook-saw-branch.txt")
    try await repo.coordinator.create(branch: "done", in: project, settings: repo.trees)
    let worktree = try #require(
      try await repo.coordinator.git.list(project).first { $0.branch == "done" })

    try await repo.coordinator.remove(worktree, deletingBranch: true, in: project)

    #expect(try await repo.branches() == ["main"])
    let seen = try String(
      contentsOf: project.path.appendingPathComponent("hook-saw-branch.txt"), encoding: .utf8)
    #expect(!seen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "the hook ran first")
  }

  @Test func aBranchWithItsOwnCommitsIsRefusedThenForced() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "unmerged", in: repo.project, settings: repo.trees)
    try "work\n".write(to: path.appendingPathComponent("w.txt"), atomically: true, encoding: .utf8)
    _ = try await repo.git.run(["add", "."], in: path)
    _ = try await repo.git.run(["commit", "-q", "-m", "unmerged"], in: path)
    let worktree = try #require(
      try await repo.coordinator.git.list(repo.project).first { $0.branch == "unmerged" })

    await #expect(throws: BranchDeletionFailure.self) {
      try await repo.coordinator.remove(worktree, deletingBranch: true, in: repo.project)
    }

    #expect(
      try await repo.coordinator.git.list(repo.project).count == 1, "the worktree is gone")
    #expect(try await repo.branches() == ["main", "unmerged"], "the branch is kept")

    try await repo.coordinator.deleteBranch("unmerged", force: true, in: repo.project)
    #expect(try await repo.branches() == ["main"])
  }

  @Test func aDetachedWorktreeHasNoBranchToDelete() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = repo.trees.worktreePath(forBranch: "detached", in: repo.project)
    try FileManager.default.createDirectory(
      at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
    _ = try await repo.git.run(
      ["worktree", "add", "-q", "--detach", path.path], in: repo.project.path)
    let worktree = try #require(
      try await repo.coordinator.git.list(repo.project).first {
        $0.isDetached && !$0.isPrimary
      })

    try await repo.coordinator.remove(worktree, deletingBranch: true, in: repo.project)

    #expect(try await repo.branches() == ["main"])
  }

  @Test func creationReportsEachStepAndSkipsHooksWithNoScript() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let steps = StepLog<WorktreeCreationStep>()

    try await repo.coordinator.create(
      branch: "plain", in: repo.project, settings: repo.trees, onStep: { steps.add($0) })
    #expect(steps.steps == [.addingWorktree], "no hooks, so no hook steps")

    var hooked = repo.project
    hooked.settings = ProjectSettings(preCreateHook: "true", postCreateHook: "true")
    steps.clear()
    try await repo.coordinator.create(
      branch: "hooked", in: hooked, settings: repo.trees, onStep: { steps.add($0) })
    #expect(steps.steps == [.preCreateHook, .addingWorktree])

    var refused = repo.project
    refused.settings = ProjectSettings(preCreateHook: "exit 1", postCreateHook: "true")
    steps.clear()
    await #expect(throws: HookFailure.self) {
      try await repo.coordinator.create(
        branch: "refused", in: refused, settings: repo.trees, onStep: { steps.add($0) })
    }
    #expect(steps.steps == [.preCreateHook], "nothing past the veto")
  }

  @Test func addStopsBeforeThePostHookWhichRunPostCreateThenRuns() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(
      preCreateHook: "echo pre > pre.txt", postCreateHook: "echo post > post.txt")

    let path = try await repo.coordinator.add(branch: "halves", in: project, settings: repo.trees)

    #expect(
      FileManager.default.fileExists(atPath: project.path.appendingPathComponent("pre.txt").path))
    #expect(try await repo.coordinator.git.list(project).count == 2, "the worktree exists")
    #expect(!FileManager.default.fileExists(atPath: path.appendingPathComponent("post.txt").path))

    try await repo.coordinator.runPostCreate(for: project, worktreePath: path, branch: "halves")
    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("post.txt").path))
  }

  @Test func removalReportsEachStepAndSkipsWhatDoesNotApply() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let steps = StepLog<WorktreeRemovalStep>()
    try await repo.coordinator.create(branch: "plain", in: repo.project, settings: repo.trees)
    let plain = try #require(
      try await repo.coordinator.git.list(repo.project).first { $0.branch == "plain" })

    try await repo.coordinator.remove(plain, in: repo.project, onStep: { steps.add($0) })
    #expect(steps.steps == [.removingWorktree], "no hooks, branch kept")
    #expect(WorktreeRemovalStep.first(for: repo.project) == .removingWorktree)

    var hooked = repo.project
    hooked.settings = ProjectSettings(preDeleteHook: "true", postDeleteHook: "true")
    try await repo.coordinator.create(branch: "hooked", in: hooked, settings: repo.trees)
    let worktree = try #require(
      try await repo.coordinator.git.list(hooked).first { $0.branch == "hooked" })
    steps.clear()
    try await repo.coordinator.remove(
      worktree, deletingBranch: true, in: hooked, onStep: { steps.add($0) })
    #expect(
      steps.steps == [.preDeleteHook, .removingWorktree, .postDeleteHook, .deletingBranch])
    #expect(WorktreeRemovalStep.first(for: hooked) == .preDeleteHook)
  }

  @Test func recognisesADirectoryThatIsNotARepository() async throws {
    let coordinator = WorktreeCoordinator(git: WorktreeGit(runner: try GitRunner()))
    let empty = try Scratch.directory("empty")
    defer { try? FileManager.default.removeItem(at: empty) }

    #expect(await coordinator.git.isRepository(empty) == false)
  }
}
