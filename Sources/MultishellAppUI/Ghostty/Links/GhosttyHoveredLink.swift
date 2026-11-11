import MultishellAppCore
import UniformTypeIdentifiers

/// The web address, path or file name the word under the pointer sits in, for
/// a program holding the mouse, whose links libghostty never looks for.
enum GhosttyHoveredLink {
  /// libghostty's word stops at `:`, so `https` is judged with the rest of its address.
  private static let tokenSeparators: Set<Unicode.Scalar> = [
    "\"", "'", "`", "(", ")", "[", "]", "{", "}", "<", ">", "|", "│", ",",
  ]
  private static let trailingPunctuation: Set<Character> = [".", ",", ";", ":", "!", "?"]

  /// `column` is the cell libghostty's word starts at; of several copies of the
  /// word in the line, the one starting nearest that cell is taken.
  static func link(word: String, startingAt column: Int, in line: String) -> String? {
    // libghostty's word is a run of name or of boundary, never both, so one
    // separator makes it a boundary run, `": "` among them, in no link.
    guard !word.contains(where: isSeparator) else { return nil }
    // By Character, which tracks cells where a scalar count drifts past an emoji.
    let characters = Array(line)
    let wordCharacters = Array(word)
    guard let start = nearestOccurrence(of: wordCharacters, in: characters, to: column) else {
      return link(inToken: word)
    }
    var lower = start
    while lower > 0, !isSeparator(characters[lower - 1]) { lower -= 1 }
    var upper = start + wordCharacters.count
    while upper < characters.count, !isSeparator(characters[upper]) { upper += 1 }
    let carried = lower > 0 ? combiningMarks(fusedOnto: characters[lower - 1]) : ""
    return link(inToken: carried + String(characters[lower..<upper]))
  }

  /// The copy whose first cell is nearest `column`, a wide character before it
  /// counting the two cells it takes.
  private static func nearestOccurrence(
    of word: [Character],
    in line: [Character],
    to column: Int,
  ) -> Int? {
    guard !word.isEmpty, word.count <= line.count else { return nil }
    var cellOffsets: [Int] = []
    var cells = 0
    for character in line {
      cellOffsets.append(cells)
      cells += TerminalCellWidth.cells(of: character)
    }
    return (0...(line.count - word.count))
      .filter { line[$0..<($0 + word.count)].elementsEqual(word) }
      .min { abs(cellOffsets[$0] - column) < abs(cellOffsets[$1] - column) }
  }

  /// libghostty judges a cell by its base code point, so a combining mark fused
  /// onto the separator before a name is the name's; a variation selector is not.
  private static func combiningMarks(fusedOnto separator: Character) -> String {
    let marks = separator.unicodeScalars.dropFirst().filter { scalar in
      [.nonspacingMark, .spacingMark, .enclosingMark].contains(scalar.properties.generalCategory)
        && !scalar.properties.isVariationSelector
    }
    return String(String.UnicodeScalarView(marks))
  }

  /// Judged by its base code point, as libghostty judges a cell.
  private static func isSeparator(_ character: Character) -> Bool {
    guard let base = character.unicodeScalars.first else { return false }
    return base.properties.isWhitespace || tokenSeparators.contains(base)
  }

  private static func link(inToken token: String) -> String? {
    var token = Substring(token)
    while let last = token.last, trailingPunctuation.contains(last) { token = token.dropLast() }
    if isWebAddress(token) || (token.contains("/") && token.contains(where: \.isLetter)) {
      return String(token)
    }
    // The clicked-link rule reads a bare `A.swift:12` as a URL with a scheme.
    let name = token.replacing(/(:\d+){1,2}$/, with: "")
    return isFileName(name) ? String(name) : nil
  }

  private static func isWebAddress(_ token: Substring) -> Bool {
    token.contains(/^[A-Za-z][A-Za-z0-9+.\-]*:\/\/\S/) || token.contains(/^mailto:\S/)
  }

  /// One the highlighter reads, `main.rs` and `Makefile` having no type on
  /// macOS, else a type macOS knows but an app's; `e.g` and `1.2.3` are prose.
  private static func isFileName(_ name: Substring) -> Bool {
    if HighlightLanguage.language(forPath: String(name), firstLine: nil) != nil { return true }
    guard let dot = name.lastIndex(of: "."), dot != name.startIndex,
      let type = UTType(filenameExtension: String(name[name.index(after: dot)...]))
    else { return false }
    return !type.isDynamic && !type.conforms(to: .application)
  }
}
