import MultishellGitKit

/// What Copy puts on the pasteboard from the All changes tab: one file's part
/// as a file tab copies it, several each under `git diff`'s header for the file.
extension AllChangesDocument {
  /// As `git diff` heads a file, renames being off: an added file's old side
  /// and a deleted one's new side are `/dev/null`.
  private static func diffHeader(of change: AllChangesFileChange) -> String {
    let old = change.kind == .added ? "/dev/null" : "a/" + change.path
    let new = change.kind == .deleted ? "/dev/null" : "b/" + change.path
    return "diff --git a/\(change.path) b/\(change.path)\n--- \(old)\n+++ \(new)\n"
  }

  /// `selections` are UTF-16 ranges into `text.string`, as the view holds it.
  public func copy(selections: [Range<Int>]) -> String {
    let rows = Set(selections.flatMap { Array(text.rows(touching: $0)) }).sorted()
    let touched = rows.compactMap(section(atRow:))
    guard let first = touched.first, touched.contains(where: { $0 != first }) else {
      return text.diffCopy(selections: selections)
    }
    var copied = ""
    var start = rows.startIndex
    while start < rows.endIndex {
      let section = touched[start]
      var end = start
      while end < rows.endIndex, touched[end] == section { end += 1 }
      copied +=
        Self.diffHeader(of: sections[section].change) + text.diffLines(ofRows: rows[start..<end])
      start = end
    }
    return copied
  }
}
