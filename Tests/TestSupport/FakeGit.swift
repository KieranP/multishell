import Foundation
import TestScratch

@testable import MultishellGitKit

/// A shell script standing in for `git`, for what real git cannot do on demand: print
/// nothing, fail or refuse a given command, or run slow enough to measure concurrency.
public struct FakeGit {
  public let directory: URL
  public let runner: GitRunner

  public var coordinator: WorktreeCoordinator { TestGit.coordinator(runner: runner) }

  /// How many runs each run of a `countingOverlap` fake saw alive as it began, itself
  /// included, one entry a run.
  public var overlaps: [Int] {
    let text = try? String(
      contentsOf: directory.appendingPathComponent("overlaps"),
      encoding: .utf8,
    )
    return (text ?? "").split(whereSeparator: \.isNewline).compactMap { line in
      Int(line.trimmingCharacters(in: .whitespaces))
    }
  }

  /// `$SCRATCH` is set inline to `directory`, since `GitRunner` passes no environment. With
  /// `loggingCalls`, each run appends its arguments to `$SCRATCH/calls` before `body` runs.
  public static func make(
    _ body: String,
    in directory: URL? = nil,
    loggingCalls: Bool = false,
  ) throws -> Self {
    let directory = try directory ?? Scratch.directory("fakegit")
    let log = loggingCalls ? "echo \"$*\" >> \"$SCRATCH/calls\"\n" : ""
    let script = try Scratch.script(
      "SCRATCH=\"\(directory.path)\"\n\(log)\(body)",
      at: directory.appendingPathComponent("fake-git-\(UUID().uuidString)"),
    )
    return Self(directory: directory, runner: try GitRunner(executable: script))
  }

  /// Each run of `command`, or of any command when it is nil, notes how many runs are alive
  /// beside it, holds for a second, then runs `reply`; other commands print nothing.
  public static func countingOverlap(
    replying reply: String,
    toOnly command: String? = nil,
  ) throws -> Self {
    // At half a second, a runner slow to spawn the next shells saw each wave leave
    // before the next arrived, and read as serial.
    let counted = """
      mkdir -p "$SCRATCH/running"
      : > "$SCRATCH/running/$$"
      ls "$SCRATCH/running" | wc -l >> "$SCRATCH/overlaps"
      sleep 1
      rm "$SCRATCH/running/$$"
      \(reply)
      """
    guard let command else { return try make(counted) }
    return try make("case \"$1\" in\n\(command))\n\(counted) ;;\nesac")
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
