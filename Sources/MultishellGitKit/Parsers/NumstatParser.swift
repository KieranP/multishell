/// Parses `git diff --numstat -z` with renames off: `<added>\t<removed>\t<path>`
/// a record, with `-` for both counts where the file is binary.
enum NumstatParser {
  static func parse(_ output: String) -> [String: StatusChange.Lines] {
    var linesByPath: [String: StatusChange.Lines] = [:]
    for record in output.split(separator: "\0", omittingEmptySubsequences: true) {
      let fields = record.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
      guard fields.count == 3, !fields[2].isEmpty else { continue }
      let added = Int(fields[0])
      let removed = Int(fields[1])
      // Both columns are `-` on a binary file and numbers otherwise. Taking
      // anything else as zero put a file with no lines on the badge.
      let isBinary = fields[0] == "-" && fields[1] == "-"
      guard isBinary || (added != nil && removed != nil) else { continue }
      let path = String(fields[2])
      if let added, let removed, added > 0 || removed > 0 {
        linesByPath[path] = .counted(insertions: added, deletions: removed)
      } else {
        linesByPath[path] = .unscored
      }
    }
    return linesByPath
  }
}
