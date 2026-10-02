import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit
@testable import MultishellProcess

@Suite(.serialized) @MainActor
struct AppModelWorktreeListRefreshTests {
  @Test func aWorktreeAddedOutsideTheAppIsFoundByTheWatcherTick() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let outside = harness.root.appendingPathComponent("outside", isDirectory: true)
    try await harness.addOutsideTheApp("outside", at: outside)

    await harness.model.refreshWorktreesIfRecordsChanged()

    #expect(harness.worktree(onBranch: "outside") != nil)
    #expect(harness.watcher.watched.map(\.lastPathComponent).sorted() == ["outside", "worktrees"])
  }

  @Test func aRefreshLandingAfterTheProjectWasRemovedLeavesNoTrace() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let project = harness.project
    #expect(harness.model.worktreeRecords[project.id] != nil)

    harness.model.removeProject(project)
    await harness.model.refreshWorktrees(of: project)

    #expect(harness.model.workspace.projects.isEmpty)
    #expect(harness.model.workspace.worktrees.isEmpty)
    #expect(harness.model.worktreeRecords[project.id] == nil)
    #expect(harness.model.commonGitDirectories[project.id] == nil)
    #expect(harness.model.missingProjects.isEmpty)
  }

  /// The same with git failing: the failure lands on a project that has
  /// gone, and must neither dim a stale id nor alert about it.
  @Test func aFailingRefreshLandingAfterTheProjectWasRemovedLeavesNoTrace() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let project = harness.project
    let failing = try harness.modelOnFakeGit(
      """
      case "$1 $2" in
        "worktree list") while [ ! -e "$SCRATCH/go" ]; do sleep 0.02; done; exit 128 ;;
      esac
      """)

    let refresh = Task { await failing.refreshWorktrees(of: project) }
    try await waitUntil { harness.gitCalls().contains { $0.hasPrefix("worktree list") } }
    failing.removeProject(project)
    try "".write(to: harness.root.appendingPathComponent("go"), atomically: true, encoding: .utf8)
    await refresh.value

    #expect(failing.missingProjects.isEmpty)
    #expect(failing.presentedError == nil)
  }

  /// The alert fires on a project's first failure only, so a dimmed mark left
  /// behind would cost a project later added under the same path its alert.
  @Test func aProjectRemovedWhileDimmedTakesTheMarkWithIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let project = harness.project
    try FileManager.default.removeItem(at: project.path.appendingPathComponent(".git"))
    await harness.model.refreshWorktrees(of: project)
    #expect(harness.model.missingProjects == [project.id])

    harness.model.presentedError = nil
    harness.model.removeProject(project)

    #expect(harness.model.missingProjects.isEmpty)

    await harness.model.addProject(at: project.path)
    #expect(harness.model.presentedError != nil, "still unreadable, and said so again")
  }

  @Test func aRepositoryGitCanNoLongerReadIsReportedOnceThenDimmed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let project = harness.project
    try FileManager.default.removeItem(at: project.path.appendingPathComponent(".git"))

    await harness.model.refreshWorktrees(of: project)
    let first = try #require(harness.model.presentedError)
    #expect(first.title.hasPrefix("git worktree list failed"))
    #expect(harness.model.missingProjects == [project.id])

    harness.model.presentedError = nil
    await harness.model.refreshWorktreesIfRecordsChanged()
    await harness.model.refreshWorktrees(of: project)

    #expect(
      harness.model.presentedError == nil, "the same failure on every tick is one alert, not many")
    #expect(harness.model.workspace.projects.count == 1)
  }

  /// What the descriptor limit used to produce: git "succeeds" and lists
  /// nothing. The project must keep what it had and say something went wrong.
  @Test func aRefreshWhereGitListsNothingKeepsTheWorktreesAndTheirTabs() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let project = harness.project
    harness.model.select(harness.worktree(onBranch: "main")!)
    #expect(harness.model.liveTerminalCount == 1)

    let muted = try harness.modelOnFakeGit("exit 0")

    await muted.refreshWorktrees(of: project)

    #expect(muted.workspace.worktrees(of: project.id).count == 1, "nothing was dropped")
    #expect(muted.workspace.tabs.count == 1)
    #expect(muted.presentedError != nil)
    #expect(muted.missingProjects == [project.id])
  }

  /// The watched directories also hold each worktree's `index`, which every
  /// `git status` rewrites, so most ticks mean nothing.
  @Test func aTickWithUnchangedRecordsSpawnsNoGitAndAChangedHEADDoes() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let repository = harness.project.path.path
    let counting = try harness.modelOnFakeGit(
      """
      case "$1 $2" in
        "rev-parse --path-format=absolute") printf '%s/.git\\n' "\(repository)" ;;
        "worktree list") printf 'worktree %s\\nHEAD 1111111\\nbranch refs/heads/main\\n' "\(repository)" ;;
      esac
      """)
    func listings() -> Int { harness.gitCallCount(startingWith: "worktree list") }

    await counting.refreshWorktreesIfRecordsChanged()
    #expect(listings() == 1, "no records yet, so a full refresh")

    await counting.refreshWorktreesIfRecordsChanged()
    await counting.refreshWorktreesIfRecordsChanged()
    #expect(listings() == 1, "nothing changed, so nothing was spawned")
    #expect(
      harness.gitCallCount(startingWith: "rev-parse") == 1, "the common dir is cached"
    )

    _ = try await harness.git.run(["checkout", "-q", "-b", "moved"], in: harness.project.path)
    await counting.refreshWorktreesIfRecordsChanged()
    #expect(listings() == 2, "HEAD changed, so git was asked again")
  }

  @Test func anExplicitRefreshReportsAFailureAlreadyShown() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let project = harness.project
    try FileManager.default.removeItem(at: project.path.appendingPathComponent(".git"))
    await harness.model.refreshWorktrees(of: project)
    #expect(harness.model.presentedError != nil)
    harness.model.presentedError = nil
    await harness.model.refreshWorktrees(of: project)
    #expect(harness.model.presentedError == nil, "a tick stays quiet")

    await harness.model.refreshWorktreesOnRequest(of: project)

    #expect(harness.model.presentedError != nil, "the user asked, so the answer is shown again")
    #expect(harness.model.missingProjects == [project.id])
  }

  @Test func aProjectWhoseDirectoryVanishesIsDimmedNotDropped() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let project = harness.project
    harness.model.select(harness.worktree(onBranch: "main")!)
    try FileManager.default.removeItem(at: project.path)

    await harness.model.refreshWorktrees(of: project)

    #expect(
      harness.model.workspace.projects.count == 1, "an unmounted drive must not delete the setup")
    #expect(harness.model.missingProjects == [project.id])
    #expect(harness.model.workspace.worktrees(of: project.id).count == 1, "kept as last seen")
  }

  @Test func aTickNamingOneProjectsRecordsLeavesTheOtherProjectUnread() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let other = try await harness.addSecondProject()
    let common = try #require(await harness.model.commonGitDirectory(of: harness.project))
    _ = try await harness.git.run(
      ["worktree", "add", "-b", "quiet", harness.root.appendingPathComponent("quiet").path],
      in: other.path)
    harness.watcher.watched = []

    await harness.model.refreshWorktreesIfRecordsChanged(
      under: [common.appendingPathComponent("worktrees")])
    #expect(
      harness.model.workspace.worktrees(of: other.id).count == 1,
      "the other's records were not read")
    #expect(harness.watcher.watched.isEmpty, "nothing changed, so nothing was re-armed")

    await harness.model.refreshWorktreesIfRecordsChanged()
    #expect(harness.model.workspace.worktrees(of: other.id).count == 2)
    #expect(!harness.watcher.watched.isEmpty)
  }
}
