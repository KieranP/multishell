import Foundation
import MultishellCore

/// Many files' committed sizes in one read, for the All changes tab, which
/// asked once a file; see Docs/design/files/all-changes-tab.md.
extension WorktreeGit {
  /// Each path's size in `commit`; a path the commit lacks, or holds as no
  /// file, has none. `nil` where git cannot say.
  public func committedSizes(
    of paths: [String],
    in directory: URL,
    at commit: String,
  ) async -> [String: Int]? {
    let outputs = await Self.runs(over: paths) { chunk in
      await runner.output(
        ["--literal-pathspecs", "ls-tree", "-r", "-l", "-z", "--full-tree", commit, "--"] + chunk,
        in: directory,
      )
    }
    guard let outputs else { return nil }
    var sizes: [String: Int] = [:]
    for output in outputs {
      // Each entry: mode, type, id, the size padded, a tab, then the path.
      for entry in output.split(separator: "\0") {
        guard let tab = entry.firstIndex(of: "\t") else { continue }
        let fields = entry[..<tab].split(separator: " ")
        guard fields.count == 4, fields[1] == "blob", let size = Int(fields[3]) else { continue }
        sizes[String(entry[entry.index(after: tab)...])] = size
      }
    }
    return sizes
  }
}
