@testable import MultishellAppCore

/// A file with one block replaced: context, `HEAD`'s lines removed, the lines
/// added in their place, then context, numbered as git would.
enum ReplacedBlockFixture {
  static func rows(before: Int, removed: Int, added: Int, after: Int) -> FileTabRows {
    let leading = (0..<before).map { index in
      DiffLine(kind: .context, oldNumber: index + 1, newNumber: index + 1, text: "before \(index)")
    }
    let gone = (0..<removed).map { index in
      DiffLine(kind: .removed, oldNumber: before + index + 1, newNumber: nil, text: "old \(index)")
    }
    let new = (0..<added).map { index in
      DiffLine(kind: .added, oldNumber: nil, newNumber: before + index + 1, text: "new \(index)")
    }
    let trailing = (0..<after).map { index in
      DiffLine(
        kind: .context,
        oldNumber: before + removed + index + 1,
        newNumber: before + added + index + 1,
        text: "after \(index)",
      )
    }
    return FileTabRows(lines: leading + gone + new + trailing)
  }
}
