extension Array where Element == FileTreeRow {
  /// A level's indent is about two characters of the panel's text.
  private static var charactersPerLevel: Int { 2 }
  /// The `+` and `−` and the space between them.
  private static var lineCountMarks: Int { 3 }
  /// A comment badge's bubble and the space before it.
  private static var commentBadgeMarks: Int { 2 }

  private static func estimatedCharacters(of row: FileTreeRow, pendingComments: Int) -> Int {
    let counts = row.lineCounts.map { counts in
      String(counts.insertions).count + String(counts.deletions).count + lineCountMarks
    }
    let badge = pendingComments > 0 ? String(pendingComments).count + commentBadgeMarks : 0
    return row.depth * charactersPerLevel + row.name.count + (row.parentFolder?.count ?? 0)
      + (counts ?? 0) + badge
  }

  /// The rows likeliest to be widest, judged by their characters and comment badges:
  /// laying out 10,000 rows to fit the panel took 3 s, so only these are laid out.
  public func likeliestWidest(_ count: Int, pendingComments: [String: Int]) -> [FileTreeRow] {
    map { row in
      (
        row: row,
        characters: Self.estimatedCharacters(
          of: row,
          pendingComments: row.pendingComments(in: pendingComments),
        ),
      )
    }
    .sorted { $0.characters > $1.characters }
    .prefix(count)
    .map(\.row)
  }
}
