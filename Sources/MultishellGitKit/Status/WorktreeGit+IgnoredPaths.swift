import Foundation
import MultishellCore
import MultishellProcess

extension WorktreeGit {
  /// Which of `paths`, relative to `directory`, git ignores; a directory holding
  /// a tracked file is not one. `nil` where git could not answer.
  public func ignoredPaths(_ paths: [String], in directory: URL) async -> Set<String>? {
    guard !paths.isEmpty else { return [] }
    // `-z` needs `--stdin`, which the runner does not feed. A name git still
    // quotes then matches nothing, so it reads as not ignored, and is read.
    let arguments = ["-c", "core.quotePath=false", "check-ignore", "--"] + paths
    // Exit 1 is "none ignored", an answer like any other.
    guard let outcome = await runner.capture(arguments, in: directory),
      outcome.status == 0 || outcome.status == 1
    else { return nil }
    return Set(outcome.standardOutput.split(whereSeparator: \.isNewline).map(String.init))
  }
}
