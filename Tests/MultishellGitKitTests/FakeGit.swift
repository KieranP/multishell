import Foundation
import TestScratch

@testable import MultishellGitKit

/// A shell script standing in for `git`, for what real git cannot show on demand:
/// printing nothing, or being slow enough that concurrency can be measured.
struct FakeGit {
  let directory: URL
  let runner: GitRunner

  /// `$SCRATCH` is set inline to the scratch directory, since `GitRunner` passes no environment.
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
