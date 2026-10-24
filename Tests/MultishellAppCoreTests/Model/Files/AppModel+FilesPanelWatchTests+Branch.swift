import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

extension AppModelFilesPanelWatchTests {
  @Test func aCommitDroppedWithTheStatusUnmovedLeavesBranchOnItsGitEvent() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    try await TestRepository.commit(
      "work",
      files: ["work.txt": "work\n"],
      in: feature.path,
      using: harness.git,
    )
    let names = { harness.model.fileTreeRows(of: feature.id).map(\.name) }
    harness.model.setChangeScope(.branch)
    try await waitUntil { names() == ["work.txt"] }
    try await harness.statusReadsSettle(feature)
    try await waitUntil { !harness.model.branchChangesReads.isRunning(feature.id) }
    _ = try await harness.git.run(["reset", "-q", "--hard", "HEAD~1"], in: feature.path)

    await harness.model.noteFileChanges([harness.project.path.appending(path: ".git/refs/heads")])

    try await waitUntil { names() == [] }
    #expect(names() == [])
  }
}
