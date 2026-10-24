/// Parses `git diff-index --raw --numstat -z` with renames off: each raw
/// record, a header then its path, then the counts `NumstatParser` reads.
enum RawNumstatParser {
  /// A path with a raw record and no count had only its stat move.
  static func parse(_ output: String) -> [StatusChange] {
    let records = output.split(separator: "\0", omittingEmptySubsequences: false)
    var kinds: [String: StatusChange.Kind] = [:]
    var index = records.startIndex
    while index + 1 < records.endIndex, records[index].hasPrefix(":") {
      let letter = records[index].split(separator: " ").last?.first
      kinds[String(records[index + 1])] =
        switch letter {
        case "A": .added
        case "D": .deleted
        default: .modified
        }
      index += 2
    }
    let counts = NumstatParser.parse(records[index...].joined(separator: "\0"))
    return counts.map { path, lines in
      StatusChange(path: path, kind: kinds[path] ?? .modified, lines: lines)
    }
  }
}
