import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

extension AppModelWorktreeOrderTests {
  /// Paths are ids, so a project added again gets its old worktree ids, and dates read
  /// before it left would order its rows until the first poll answered.
  @Test func removingAProjectForgetsItsCommitDates() {
    let harness = Harness()
    harness.model.lastCommits[harness.main.id] = Date(timeIntervalSince1970: 1000)
    harness.model.lastCommits[harness.feature.id] = Date(timeIntervalSince1970: 2000)

    harness.model.removeProject(harness.project)
    #expect(harness.model.lastCommits.isEmpty)
  }

  /// The same call forgets the merge badges; losing the dates too would leave a trunk-less
  /// repository with nothing to order by.
  @Test func losingTheDefaultBranchKeepsTheCommitDates() {
    let harness = Harness()
    harness.model.lastCommits[harness.feature.id] = Date(timeIntervalSince1970: 2000)
    harness.model.mergeStates[harness.feature.id] = .unmerged

    harness.model.forgetMergeStates(ofProject: harness.project.id)
    #expect(harness.model.mergeStates.isEmpty, "the badges go")
    #expect(harness.model.lastCommits.count == 1, "the dates stay")
  }
}
