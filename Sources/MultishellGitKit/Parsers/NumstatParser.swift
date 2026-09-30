/// Parses `git diff --numstat`: `<added>\t<removed>\t<path>` a line, with `-`
/// for both counts where the file is binary.
enum NumstatParser {
  static func parse(_ output: String) -> LineCounts {
    var counts = LineCounts()
    for line in output.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) {
      let fields = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
      guard fields.count >= 3, !fields[2].isEmpty else { continue }
      let added = Int(fields[0])
      let removed = Int(fields[1])
      // Both columns are `-` on a binary file and numbers otherwise. Taking
      // anything else as zero put a file with no lines on the badge.
      let isBinary = fields[0] == "-" && fields[1] == "-"
      guard isBinary || (added != nil && removed != nil) else { continue }
      counts.insertions += added ?? 0
      counts.deletions += removed ?? 0
      if (added ?? 0) == 0 && (removed ?? 0) == 0 { counts.unscoredFiles += 1 }
    }
    return counts
  }
}
