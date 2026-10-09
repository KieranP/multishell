import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite(.serialized) @MainActor
struct AppModelFetchTests {
  /// A fetch waits on a network, so the sidebar has to say it is happening
  /// and a second click must not start another one.
  @Test func aFetchMarksItsProjectForAllOfItAndRefusesASecond() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let model = try harness.modelOnFakeGit(
      """
      case "$*" in
        fetch*) sleep 1; touch "$SCRATCH/fetched" ;;
        worktree\\ list*)
          printf 'worktree %s\\nHEAD abc\\nbranch refs/heads/main\\n\\n' "$SCRATCH/demo" ;;
        for-each-ref*)
          if [ -e "$SCRATCH/fetched" ]; then touch "$SCRATCH/rereading"; sleep 0.5; fi
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

    let rereading = harness.root.appendingPathComponent("rereading")
    try await waitUntil { FileManager.default.fileExists(atPath: rereading.path) }
    #expect(model.isFetching(project), "the re-reads after it are what the user clicked for")

    await running.value
    #expect(!model.isFetching(project))
    #expect(harness.gitCallCount(startingWith: "fetch") == 1, "one fetch, not two")
  }
}
