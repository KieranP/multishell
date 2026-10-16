/// Parses `ls-files -z -t --cached --stage`, `<tag> <mode> <object>
/// <stage>\t<path>` a record; a conflicted path, listed once a stage, is kept once.
enum TrackedFileListParser {
  private static let gitlinkMode = "160000"
  /// git's tag for a path a sparse checkout leaves off disk.
  private static let skipWorktreeTag = "S"

  static func parse(_ output: String, limit: Int) -> TrackedFiles {
    var paths: [String] = []
    var submodules: Set<String> = []
    var notCheckedOut: Set<String> = []
    var seen: Set<Substring> = []
    var isCapped = false
    for record in output.split(separator: "\0", omittingEmptySubsequences: true) {
      guard let tab = record.firstIndex(of: "\t"), let space = record.firstIndex(of: " ") else {
        continue
      }
      let path = record[record.index(after: tab)...]
      guard !path.isEmpty, seen.insert(path).inserted else { continue }
      guard paths.count < limit else {
        isCapped = true
        break
      }
      let text = String(path)
      paths.append(text)
      let fields = record[record.index(after: space)..<tab]
      if fields.hasPrefix(gitlinkMode + " ") { submodules.insert(text) }
      if record[..<space] == skipWorktreeTag { notCheckedOut.insert(text) }
    }
    return TrackedFiles(
      paths: paths,
      submodulePaths: submodules,
      notCheckedOutPaths: notCheckedOut,
      isCapped: isCapped,
    )
  }
}
