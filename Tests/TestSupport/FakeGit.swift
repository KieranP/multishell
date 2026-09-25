import Foundation
import TestScratch

@testable import MultishellGitKit

/// A shell script standing in for `git`, for what real git cannot show on demand:
/// printing nothing, or being slow enough that concurrency can be measured.
public struct FakeGit {
  public let directory: URL
  public let runner: GitRunner

  /// `$SCRATCH` is set inline to `directory`, since `GitRunner` passes no environment. With
  /// `loggingCalls`, each run appends its arguments to `$SCRATCH/calls` before `body` runs.
  public static func make(
    _ body: String, in directory: URL? = nil, loggingCalls: Bool = false
  ) throws -> FakeGit {
    let directory = try directory ?? Scratch.directory("fakegit")
    let log = loggingCalls ? "echo \"$*\" >> \"$SCRATCH/calls\"\n" : ""
    let script = try Scratch.script(
      "SCRATCH=\"\(directory.path)\"\n\(log)\(body)",
      at: directory.appendingPathComponent("fake-git-\(UUID().uuidString)"))
    return FakeGit(directory: directory, runner: try GitRunner(executable: script))
  }

  /// The arguments of every logged run in `directory`, oldest first.
  public static func calls(in directory: URL) -> [String] {
    (try? String(contentsOf: directory.appendingPathComponent("calls"), encoding: .utf8))?
      .split(whereSeparator: \.isNewline).map(String.init) ?? []
  }

  public func tearDown() {
    Scratch.remove(directory)
  }
}
