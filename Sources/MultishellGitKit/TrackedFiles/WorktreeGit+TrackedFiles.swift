import Foundation

/// What the Files panel lists of a worktree's index; see Docs/design/files.md.
extension WorktreeGit {
  /// 50,000 cut Linux's 96,000 in half; Swift turns 96,000 paths into strings
  /// in 19 ms and 14 MB.
  public static let trackedPathLimit = 200_000

  /// From the index alone, 27 ms on Linux where `--others` too took 198 ms;
  /// new files come from status. See Docs/design/files.md.
  public func trackedFiles(in directory: URL) async -> TrackedFiles? {
    guard
      let output = await runner.output(
        ["--no-optional-locks", "ls-files", "-z", "-t", "--cached", "--stage"],
        in: directory,
      )
    else { return nil }
    return TrackedFileListParser.parse(output, limit: Self.trackedPathLimit)
  }
}
