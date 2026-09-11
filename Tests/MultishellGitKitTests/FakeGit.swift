import Foundation
import TestScratch

@testable import MultishellGitKit

/// A shell script standing in for `git`, for behaviour real git cannot be
/// made to show on demand: printing nothing, or being slow enough that
/// concurrency can be measured. The script sees its scratch directory as a
/// literal path, since `GitRunner` passes no environment.
struct FakeGit {
  let directory: URL
  let runner: GitRunner

  /// `body` runs with `$SCRATCH` set to the scratch directory.
  static func make(_ body: String) throws -> FakeGit {
    let directory = try Scratch.directory("fakegit")
    let script = try Scratch.script(
      "SCRATCH=\"\(directory.path)\"\n\(body)", at: directory.appendingPathComponent("git"))
    return FakeGit(directory: directory, runner: try GitRunner(executable: script))
  }

  func tearDown() {
    Scratch.remove(directory)
  }
}
