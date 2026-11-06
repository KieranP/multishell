extension Array where Element == FileTreeRow {
  /// A level's indent is about two characters of the panel's text.
  private static var charactersPerLevel: Int { 2 }
  /// The `+` and `−` and the space between them.
  private static var lineCountMarks: Int { 3 }

  private static func estimatedCharacters(of row: FileTreeRow) -> Int {
    let counts = row.lineCounts.map { counts in
      String(counts.insertions).count + String(counts.deletions).count + lineCountMarks
    }
    return row.depth * charactersPerLevel + row.name.count + (row.parentFolder?.count ?? 0)
      + (counts ?? 0)
  }

  /// The rows likeliest to be widest, judged by their characters: laying out
  /// 10,000 rows to fit the panel took 3 s, so only these are laid out.
  public func likeliestWidest(_ count: Int) -> [FileTreeRow] {
    map { (row: $0, characters: Self.estimatedCharacters(of: $0)) }
      .sorted { $0.characters > $1.characters }
      .prefix(count)
      .map(\.row)
  }
}
