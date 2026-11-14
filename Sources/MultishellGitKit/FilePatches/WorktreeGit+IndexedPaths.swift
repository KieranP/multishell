import Foundation
import MultishellCore

/// Which of many paths the index holds, in one read, for the All changes tab:
/// a file it lacks and no commit holds is new, its diffs empty.
extension WorktreeGit {
  /// The paths of `paths` the index holds; `nil` where git cannot say.
  public func indexedPaths(_ paths: [String], in directory: URL) async -> Set<String>? {
    let outputs = await Self.runs(over: paths) { chunk in
      await runner.output(
        ["--literal-pathspecs", "ls-files", "-z", "--cached", "--full-name", "--"] + chunk,
        in: directory,
      )
    }
    return outputs.map { outputs in
      Set(outputs.flatMap { $0.split(separator: "\0").map(String.init) })
    }
  }
}
