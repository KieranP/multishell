import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

/// End-to-end against a real repository in a temporary directory.
@Suite(.serialized)
struct WorktreeCoordinatorTests {
  private let git = try! GitRunner()

  private func makeRepository() async throws -> (root: URL, project: Project) {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-tests-\(UUID().uuidString)", isDirectory: true)
    let repository = root.appendingPathComponent("demo", isDirectory: true)
    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)

    _ = try await git.run(["init", "--initial-branch=main"], in: repository)
    _ = try await git.run(["config", "user.email", "tests@multishell.local"], in: repository)
    _ = try await git.run(["config", "user.name", "Multishell Tests"], in: repository)
    try "hello\n".write(
      to: repository.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    _ = try await git.run(["add", "."], in: repository)
    _ = try await git.run(["commit", "-m", "initial"], in: repository)

    return (root, Project(path: repository))
  }

  @Test func createsAWorktreeWhereTheSettingsSayAndRunsTheHook() async throws {
    let (root, base) = try await makeRepository()
    defer { try? FileManager.default.removeItem(at: root) }

    var project = base
    project.settings = ProjectSettings(postCreateHook: "echo created > hook.txt")
    let settings = WorktreeSettings(worktreeDirectory: "../trees", branchPrefix: "kieran/")

    let coordinator = WorktreeCoordinator(service: WorktreeService(git: git))
    let path = try await coordinator.create(branch: "tabs", in: project, settings: settings)

    #expect(path.lastPathComponent == "kieran-tabs")
    #expect(path.deletingLastPathComponent().lastPathComponent == "trees")
    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("hook.txt").path))

    let worktrees = try await coordinator.refresh(project)
    #expect(worktrees.count == 2)
    #expect(worktrees.contains { $0.branch == "kieran/tabs" })
  }

  @Test func removesAWorktreeAndRunsTheDeleteHook() async throws {
    let (root, base) = try await makeRepository()
    defer { try? FileManager.default.removeItem(at: root) }

    var project = base
    project.settings = ProjectSettings(postDeleteHook: "echo gone > deleted.txt")
    let settings = WorktreeSettings(worktreeDirectory: "../trees")

    let coordinator = WorktreeCoordinator(service: WorktreeService(git: git))
    try await coordinator.create(branch: "scratch", in: project, settings: settings)

    let worktree = try await coordinator.refresh(project).first { $0.branch == "scratch" }
    try await coordinator.remove(#require(worktree), in: project)

    #expect(try await coordinator.refresh(project).count == 1)
    #expect(
      FileManager.default.fileExists(
        atPath: project.path.appendingPathComponent("deleted.txt").path))
  }

  @Test func aFailingHookLeavesTheWorktreeInPlace() async throws {
    let (root, base) = try await makeRepository()
    defer { try? FileManager.default.removeItem(at: root) }

    var project = base
    project.settings = ProjectSettings(postCreateHook: "exit 3")
    let settings = WorktreeSettings(worktreeDirectory: "../trees")

    let coordinator = WorktreeCoordinator(service: WorktreeService(git: git))
    await #expect(throws: HookFailure.self) {
      try await coordinator.create(branch: "doomed", in: project, settings: settings)
    }
    #expect(try await coordinator.refresh(project).contains { $0.branch == "doomed" })
  }

  @Test func recognisesADirectoryThatIsNotARepository() async throws {
    let coordinator = WorktreeCoordinator(service: WorktreeService(git: git))
    let empty = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-empty-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: empty) }

    #expect(await coordinator.isRepository(empty) == false)
  }
}

@Suite(.serialized)
struct GitIntegrationTests {
  private let git = try! GitRunner()

  private func makeRepository(commit: Bool = true) async throws -> (root: URL, project: Project) {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-tests-\(UUID().uuidString)", isDirectory: true)
    let repository = root.appendingPathComponent("demo", isDirectory: true)
    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    _ = try await git.run(["init", "--initial-branch=main"], in: repository)
    _ = try await git.run(["config", "user.email", "tests@multishell.local"], in: repository)
    _ = try await git.run(["config", "user.name", "Multishell Tests"], in: repository)
    if commit {
      try "hello\n".write(
        to: repository.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
      _ = try await git.run(["add", "."], in: repository)
      _ = try await git.run(["commit", "-m", "initial"], in: repository)
    }
    return (root, Project(path: repository))
  }

  @Test func hooksReceiveTheDocumentedEnvironment() async throws {
    let (root, base) = try await makeRepository()
    defer { try? FileManager.default.removeItem(at: root) }
    var project = base
    project.settings = ProjectSettings(
      postCreateHook:
        "printf \"%s|%s|%s|%s\" \"$MULTISHELL_PROJECT_PATH\" \"$MULTISHELL_PROJECT_NAME\" \"$MULTISHELL_WORKTREE_PATH\" \"$MULTISHELL_BRANCH\" > env.txt"
    )
    let coordinator = WorktreeCoordinator(service: WorktreeService(git: git))
    let path = try await coordinator.create(
      branch: "hooked", in: project, settings: WorktreeSettings(worktreeDirectory: "../trees"))

    let recorded = try String(contentsOf: path.appendingPathComponent("env.txt"), encoding: .utf8)
      .split(separator: "|").map(String.init)
    #expect(recorded[0] == project.path.path)
    #expect(recorded[1] == "demo")
    #expect(recorded[2] == path.path)
    #expect(recorded[3] == "hooked")
  }

  @Test func watchPathsMoveFromDotGitToWorktreesOnceOneExists() async throws {
    let (root, project) = try await makeRepository()
    defer { try? FileManager.default.removeItem(at: root) }
    let coordinator = WorktreeCoordinator(service: WorktreeService(git: git))

    let before = await coordinator.directoriesToWatch(for: project)
    #expect(before.map(\.lastPathComponent) == [".git"])

    try await coordinator.create(
      branch: "one", in: project, settings: WorktreeSettings(worktreeDirectory: "../trees"))
    let after = await coordinator.directoriesToWatch(for: project)
    #expect(after.map(\.lastPathComponent) == ["worktrees", "one"])
  }

  @Test func statusReflectsWorkingTreeChangesAndBranch() async throws {
    let (root, project) = try await makeRepository()
    defer { try? FileManager.default.removeItem(at: root) }
    let service = WorktreeService(git: git)
    let main = try await service.list(project)[0]

    #expect(try await service.status(of: main).isClean)

    try "changed\n".write(
      to: project.path.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    try "new\n".write(
      to: project.path.appendingPathComponent("scratch.txt"), atomically: true, encoding: .utf8)
    let dirty = try await service.status(of: main)

    #expect(dirty.unstaged == 1)
    #expect(dirty.untracked == 1)
    #expect(dirty.changedFiles == 2)
    #expect(dirty.branch == "main")
  }

  @Test func removingAWorktreeWhoseDirectoryIsGonePrunesIt() async throws {
    let (root, project) = try await makeRepository()
    defer { try? FileManager.default.removeItem(at: root) }
    let coordinator = WorktreeCoordinator(service: WorktreeService(git: git))
    let path = try await coordinator.create(
      branch: "ghost", in: project, settings: WorktreeSettings(worktreeDirectory: "../trees"))
    try FileManager.default.removeItem(at: path)

    let ghost = try #require(try await coordinator.refresh(project).first { $0.branch == "ghost" })
    try await coordinator.remove(ghost, in: project)

    #expect(try await coordinator.refresh(project).count == 1)
  }

  @Test func hasCommitsIsFalseUntilTheFirstCommit() async throws {
    let (root, project) = try await makeRepository(commit: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let coordinator = WorktreeCoordinator(service: WorktreeService(git: git))

    #expect(await coordinator.hasCommits(project) == false)
    try "x\n".write(to: project.path.appendingPathComponent("f"), atomically: true, encoding: .utf8)
    _ = try await git.run(["add", "."], in: project.path)
    _ = try await git.run(["commit", "-m", "first"], in: project.path)
    #expect(await coordinator.hasCommits(project) == true)
  }

  @Test func remoteBranchesComeFromRefsRemotesWithoutHEAD() async throws {
    let (root, upstream) = try await makeRepository()
    defer { try? FileManager.default.removeItem(at: root) }
    _ = try await git.run(["branch", "feature"], in: upstream.path)
    let clone = root.appendingPathComponent("clone", isDirectory: true)
    _ = try await git.run(["clone", "-q", upstream.path.path, clone.path], in: root)

    let branches = try await WorktreeService(git: git).remoteBranches(Project(path: clone))
    #expect(branches.sorted() == ["origin/feature", "origin/main"])
  }
}
