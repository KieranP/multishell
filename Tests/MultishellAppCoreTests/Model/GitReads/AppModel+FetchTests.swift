import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelFetchTests {
  @Test func anUpstreamAScanRecordedDuringTheFetchIsReadOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    let before = try await harness.tip(of: feat)
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "more"], in: feat.path)
    _ = try await harness.git.run(["push", "-q", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(
      ["update-ref", "refs/remotes/origin/feat", before],
      in: feat.path,
    )
    let fetched = harness.root.appendingPathComponent("fetched")
    let gate = harness.root.appendingPathComponent("fetch-gate")
    let wrapper = try Scratch.script(
      """
      case "$1" in
        fetch) git "$@"; status=$?; /usr/bin/touch '\(fetched.path)'; \(harness.holdLine(until: gate)); exit $status ;;
      esac
      exec git "$@"
      """,
      at: harness.root.appendingPathComponent("fake-git"),
    )
    harness.model.coordinator = TestGit.coordinator(
      runner: try GitRunner(executable: wrapper, configuration: ["commit.gpgsign": "false"])
    )
    let fetch = Task { await harness.model.fetch(harness.project) }
    try await waitUntil { FileManager.default.fileExists(atPath: fetched.path) }

    await harness.model.refreshBranchScan(of: harness.project)
    try await waitUntil { host.calls.count == 2 }
    try Data().write(to: gate)
    await fetch.value
    try await waitUntil { harness.servicesAreSettled() }

    #expect(host.calls == ["list", "list"])
  }

  /// A fetch waits on a network, so the sidebar has to say it is happening
  /// and a second click must not start another one.
  @Test func aFetchMarksItsProjectForAllOfItAndRefusesASecond() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let fetchGate = harness.root.appendingPathComponent("fetch-gate")
    let rereadGate = harness.root.appendingPathComponent("reread-gate")
    let model = try harness.modelOnFakeGit(
      """
      case "$*" in
        fetch*)
          \(harness.holdLine(until: fetchGate))
          touch "$SCRATCH/fetched" ;;
        worktree\\ list*)
          printf 'worktree %s\\nHEAD abc\\nbranch refs/heads/main\\n\\n' "$SCRATCH/demo" ;;
        for-each-ref*)
          if [ -e "$SCRATCH/fetched" ]; then
            touch "$SCRATCH/rereading"
            \(harness.holdLine(until: rereadGate))
          fi
          printf 'refs/heads/main\\tAAA\\t\\t\\n' ;;
        *) exit 0 ;;
      esac
      """
    )
    let project = harness.project
    #expect(!model.isFetching(project))

    let running = Task { await model.fetch(project) }
    for _ in 0..<200 where !model.isFetching(project) { await Task.yield() }
    #expect(model.isFetching(project), "marked before it waits on anything")

    // The menu item is disabled by this, but a keyboard repeat or a second
    // window must not get past it either.
    await model.fetch(project)
    #expect(model.isFetching(project), "the first one is still running")

    try Data().write(to: fetchGate)
    let rereading = harness.root.appendingPathComponent("rereading")
    try await waitUntil { FileManager.default.fileExists(atPath: rereading.path) }
    #expect(model.isFetching(project), "the re-reads after it are what the user clicked for")

    try Data().write(to: rereadGate)
    await running.value
    #expect(!model.isFetching(project))
    #expect(harness.gitCallCount(startingWith: "fetch") == 1, "one fetch, not two")
  }

  @Test func aFetchRereadsOnlyItsOwnProjectsRows() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let otherProject = try await harness.addSecondProject()
    let otherMain = try #require(harness.model.workspace.worktrees(of: otherProject.id).first)
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.clearStatuses()
    var unread = WorktreeStatus()
    unread.branch = "main"
    unread.changedFiles = 99
    harness.model.statuses = [otherMain.id: unread]

    await harness.model.fetch(harness.project)

    #expect(harness.model.statuses[main.id] != nil)
    #expect(harness.model.statuses[otherMain.id] == unread)
  }

  @Test func aFetchMovingAnUpstreamReadsTheServicesOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "more"], in: feat.path)
    _ = try await harness.git.run(["push", "-q", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(
      ["update-ref", "refs/remotes/origin/feat", "feat~1"],
      in: feat.path,
    )
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    await harness.model.fetch(harness.project)
    try await waitUntil { harness.servicesAreSettled() }

    #expect(host.calls == ["list", "list"])
  }

  @Test func aFetchMovingAnUpstreamBeforeAnyReadReadsTheServices() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "more"], in: feat.path)
    _ = try await harness.git.run(["push", "-q", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(
      ["update-ref", "refs/remotes/origin/feat", "feat~1"],
      in: feat.path,
    )
    await harness.model.refreshBranchScan(of: harness.project)

    await harness.model.fetch(harness.project)
    try await waitUntil { harness.servicesAreSettled() }

    #expect(host.calls == ["list"])
  }

  @Test func aFetchThatOnlyLosesAWorktreeStillReadsTheServices() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    _ = try await harness.git.run(
      ["worktree", "remove", "--force", feat.path.path],
      in: harness.project.path,
    )

    await harness.model.fetch(harness.project)
    try await waitUntil { harness.servicesAreSettled() }

    #expect(host.calls == ["list", "list"])
  }
}
