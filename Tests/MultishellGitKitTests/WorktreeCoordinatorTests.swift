import Foundation
import MultishellCore
import MultishellProcess
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

  @Test func aFailingPreCreateHookLeavesNoWorktreeAndNoBranch() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(preCreateHook: "echo refused >&2\nexit 7")

    await #expect(throws: HookFailure.self) {
      try await repo.coordinator.create(branch: "refused", in: project, settings: repo.trees)
    }

    #expect(try await repo.coordinator.refresh(project).count == 1)
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
      try await repo.coordinator.refresh(project).first { $0.branch == "kept" })

    await #expect(throws: HookFailure.self) {
      try await repo.coordinator.remove(worktree, in: project)
    }

    #expect(FileManager.default.fileExists(atPath: path.path))
    #expect(try await repo.coordinator.refresh(project).count == 2)
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
      try await repo.coordinator.refresh(project).first { $0.branch == "leaving" })

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
    var project = repo.project
    project.settings = ProjectSettings(
      postCreateHook: "printf '%s|%s' \"$ZSH_VERSION\" \"$BASH_VERSION\" > shell.txt")

    let zsh = try await repo.coordinator.create(
      branch: "zsh", in: project, settings: repo.trees, shellPath: "/bin/zsh")
    let underZsh = try String(contentsOf: zsh.appendingPathComponent("shell.txt"), encoding: .utf8)
    #expect(underZsh.hasPrefix("|") == false && underZsh.hasSuffix("|"), "zsh set, bash not")

    let bash = try await repo.coordinator.create(
      branch: "bash", in: project, settings: repo.trees, shellPath: "/bin/bash")
    let underBash = try String(
      contentsOf: bash.appendingPathComponent("shell.txt"), encoding: .utf8)
    #expect(underBash.hasPrefix("|"), "zsh not set under bash")
    #expect(underBash.count > 1, "bash set")
  }

  @Test func removingCanDeleteTheBranchAfterThePostHookHasSeenIt() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(
      postDeleteHook: "git rev-parse --verify \"$MULTISHELL_BRANCH\" > hook-saw-branch.txt")
    try await repo.coordinator.create(branch: "done", in: project, settings: repo.trees)
    let worktree = try #require(
      try await repo.coordinator.refresh(project).first { $0.branch == "done" })

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
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "unmerged" })

    await #expect(throws: BranchDeletionFailure.self) {
      try await repo.coordinator.remove(worktree, deletingBranch: true, in: repo.project)
    }

    #expect(try await repo.coordinator.refresh(repo.project).count == 1, "the worktree is gone")
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
      try await repo.coordinator.refresh(repo.project).first { $0.isDetached && !$0.isPrimary })

    try await repo.coordinator.remove(worktree, deletingBranch: true, in: repo.project)

    #expect(try await repo.branches() == ["main"])
  }

  @Test func creationReportsEachStepAndSkipsHooksWithNoScript() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let steps = StepLog()

    try await repo.coordinator.create(
      branch: "plain", in: repo.project, settings: repo.trees, onStep: { steps.add($0) })
    #expect(steps.steps == [.addingWorktree], "no hooks, so no hook steps")

    var hooked = repo.project
    hooked.settings = ProjectSettings(preCreateHook: "true", postCreateHook: "true")
    steps.clear()
    try await repo.coordinator.create(
      branch: "hooked", in: hooked, settings: repo.trees, onStep: { steps.add($0) })
    #expect(steps.steps == [.preCreateHook, .addingWorktree, .postCreateHook])

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
    #expect(try await repo.coordinator.refresh(project).count == 2, "the worktree exists")
    #expect(!FileManager.default.fileExists(atPath: path.appendingPathComponent("post.txt").path))

    try await repo.coordinator.runPostCreate(for: project, worktreePath: path, branch: "halves")
    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("post.txt").path))
  }

  @Test func removalReportsEachStepAndSkipsWhatDoesNotApply() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let steps = RemovalStepLog()
    try await repo.coordinator.create(branch: "plain", in: repo.project, settings: repo.trees)
    let plain = try #require(
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "plain" })

    try await repo.coordinator.remove(plain, in: repo.project, onStep: { steps.add($0) })
    #expect(steps.steps == [.removingWorktree], "no hooks, branch kept")
    #expect(WorktreeRemovalStep.first(for: repo.project) == .removingWorktree)

    var hooked = repo.project
    hooked.settings = ProjectSettings(preDeleteHook: "true", postDeleteHook: "true")
    try await repo.coordinator.create(branch: "hooked", in: hooked, settings: repo.trees)
    let worktree = try #require(
      try await repo.coordinator.refresh(hooked).first { $0.branch == "hooked" })
    steps.clear()
    try await repo.coordinator.remove(
      worktree, deletingBranch: true, in: hooked, onStep: { steps.add($0) })
    #expect(
      steps.steps == [.preDeleteHook, .removingWorktree, .postDeleteHook, .deletingBranch])
    #expect(WorktreeRemovalStep.first(for: hooked) == .preDeleteHook)
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

/// Collects the steps a create reports, from whatever thread they arrive on.
private final class StepLog: @unchecked Sendable {
  private let lock = NSLock()
  private var collected: [WorktreeCreationStep] = []

  var steps: [WorktreeCreationStep] { lock.withLock { collected } }
  func add(_ step: WorktreeCreationStep) { lock.withLock { collected.append(step) } }
  func clear() { lock.withLock { collected = [] } }
}

final class RemovalStepLog: @unchecked Sendable {
  private let lock = NSLock()
  private var collected: [WorktreeRemovalStep] = []

  var steps: [WorktreeRemovalStep] { lock.withLock { collected } }
  func add(_ step: WorktreeRemovalStep) { lock.withLock { collected.append(step) } }
  func clear() { lock.withLock { collected = [] } }
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

@Suite
struct WorktreeServiceGuardTests {
  /// At the descriptor limit a child's output used to vanish and the list
  /// came back empty; taken as a result it emptied the project of its tabs.
  @Test func anEmptyWorktreeListIsAnErrorNotAResult() async throws {
    let fake = try FakeGit.make("exit 0")
    defer { fake.tearDown() }
    let project = Project(path: fake.directory)

    await #expect(throws: ProcessFailure.self) {
      try await WorktreeService(git: fake.runner).list(project)
    }
  }

  @Test func aListWithTheMainWorktreeIsFine() async throws {
    let fake = try FakeGit.make(
      "printf 'worktree /repos/demo\\nHEAD 1111111\\nbranch refs/heads/main\\n'")
    defer { fake.tearDown() }

    let listed = try await WorktreeService(git: fake.runner).list(Project(path: fake.directory))

    #expect(listed.map(\.branch) == ["main"])
  }
}

@Suite
struct StatusConcurrencyTests {
  /// Thirty `git status` at once thrash the disk; the coordinator promises at
  /// most eight. Each fake run notes how many others are running when it
  /// starts, then holds its slot for a moment.
  @Test func statusesRunAtMostEightAtATimeAndStillOverlap() async throws {
    let fake = try FakeGit.make(
      """
      mkdir -p "$SCRATCH/running" "$SCRATCH/peaks"
      : > "$SCRATCH/running/$$"
      ls "$SCRATCH/running" | wc -l > "$SCRATCH/peaks/$$"
      sleep 0.3
      rm "$SCRATCH/running/$$"
      printf '## main\\n'
      """)
    defer { fake.tearDown() }
    let worktrees = (0..<20).map {
      Worktree(path: fake.directory, projectID: "/p", head: "h\($0)", branch: "b\($0)")
    }
    // Same directory, so ids collide; the count comes from the script.
    let coordinator = WorktreeCoordinator(service: WorktreeService(git: fake.runner))

    let started = ContinuousClock.now
    let statuses = await coordinator.statuses(of: worktrees)
    let elapsed = ContinuousClock.now - started

    #expect(statuses.values.allSatisfy { $0.branch == "main" })
    let peaks = try FileManager.default.contentsOfDirectory(
      atPath: fake.directory.appendingPathComponent("peaks").path
    ).compactMap { name in
      try? String(
        contentsOf: fake.directory.appendingPathComponent("peaks/\(name)"), encoding: .utf8
      ).trimmingCharacters(in: .whitespacesAndNewlines)
    }.compactMap(Int.init)
    #expect(peaks.count == 20, "every run recorded a peak")
    #expect(peaks.max() ?? 0 <= WorktreeCoordinator.maxConcurrentStatuses, "\(peaks)")
    #expect(peaks.max() ?? 0 >= 4, "runs did not overlap: \(peaks)")
    // Twenty runs of 0.3 s: six seconds serially, under a second in threes.
    #expect(elapsed < .seconds(4), "took \(elapsed)")
  }
}

@Suite(.serialized)
struct StatusLockTests {
  /// A stale index makes a plain `git status` rewrite it under `index.lock`,
  /// which a commit typed in a terminal at that moment trips over. The
  /// background poll must read without ever writing.
  @Test func aStatusPollNeverWritesTheIndex() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let index = repo.project.path.appendingPathComponent(".git/index")
    func indexModified() throws -> Date {
      try #require(
        FileManager.default.attributesOfItem(atPath: index.path)[.modificationDate] as? Date)
    }
    let before = try indexModified()
    try await Task.sleep(for: .milliseconds(50))
    try "changed\n".write(
      to: repo.project.path.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    let main = try await repo.coordinator.refresh(repo.project)[0]

    let status = try await WorktreeService(git: repo.git).status(of: main)

    #expect(status.unstaged == 1, "the change was seen")
    #expect(try indexModified() == before, "the index was rewritten")
    #expect(
      !FileManager.default.fileExists(
        atPath: repo.project.path.appendingPathComponent(".git/index.lock").path))
  }
}
