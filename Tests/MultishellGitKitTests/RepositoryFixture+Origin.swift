import Foundation
import TestSupport

@testable import MultishellGitKit

extension RepositoryFixture {
  func addOrigin() async throws {
    try await TestRepository.addOrigin(to: project.path, in: root, using: runner)
  }

  /// Two commits, so the one the forge squashes them into shares a patch id with neither and
  /// `git cherry` cannot answer. The squash is one commit of the whole tree, then the branch goes.
  func pushThenSquashMergeOnTheRemote(
    _ branch: String, work: [(file: String, content: String)]
  ) async throws {
    _ = try await runner.run(["checkout", "-q", "-b", branch], in: project.path)
    for (index, change) in work.enumerated() {
      try await commit(
        index == 0 ? "work" : "more work", file: change.file, content: change.content)
    }
    _ = try await runner.run(["push", "-q", "-u", "origin", branch], in: project.path)
    _ = try await runner.run(["checkout", "-q", "main"], in: project.path)
    try await TestRepository.squashMergeOnTheRemote(
      branch,
      files: Dictionary(work.map { ($0.file, $0.content) }, uniquingKeysWith: { _, last in last }),
      in: project.path, using: runner)
  }
}
