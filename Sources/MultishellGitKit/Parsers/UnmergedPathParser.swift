/// Parses `git ls-files --unmerged -z`: `<mode> <object> <stage>\t<path>`, one
/// record per stage, so a path listed up to three times is kept once, in order.
enum UnmergedPathParser {
  static func parse(_ output: String) -> [String] {
    var seen: Set<String> = []
    var paths: [String] = []
    for record in output.split(separator: "\0", omittingEmptySubsequences: true) {
      guard let tab = record.firstIndex(of: "\t") else { continue }
      let path = String(record[record.index(after: tab)...])
      if seen.insert(path).inserted { paths.append(path) }
    }
    return paths
  }
}
