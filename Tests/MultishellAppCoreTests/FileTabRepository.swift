import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

/// A scratch repository a file tab reads from.
struct FileTabRepository {
  let root: URL
  let path: URL
  let runner: GitRunner
  var git: WorktreeGit { WorktreeGit(runner: runner) }

  static func make(commit: Bool = true) async throws -> Self {
    let runner = try TestGit.runner()
    let root = Scratch.path("filetab")
    let path = root.appending(path: "demo", directoryHint: .isDirectory)
    try await TestRepository.initialise(at: path, withFirstCommit: commit, using: runner)
    return Self(root: root, path: path, runner: runner)
  }

  func write(_ text: String, to file: String) throws {
    try text.write(to: path.appending(path: file), atomically: true, encoding: .utf8)
  }

  func read(
    _ file: String,
    since base: DefaultBranch? = nil,
    previous: FileTabReading? = nil,
  ) async -> FileTabReading {
    await FileTabReader.read(
      path: file,
      in: path,
      git: git,
      diffAlgorithm: .histogram,
      since: base,
      previous: previous,
      imageRule: .fake,
    )
  }

  /// `main`, as a project with no remote resolves it.
  func base() async throws -> DefaultBranch {
    try #require(
      DefaultBranch.resolve(
        from: await git.branchRefs(Project(path: path))?.refs ?? [],
        override: nil,
      )
    )
  }

  func tearDown() { Scratch.remove(root) }
}
