import MultishellAppCore
import UniformTypeIdentifiers

/// The web address, path or file name the word under the pointer sits in, for
/// a program holding the mouse, whose links libghostty never looks for.
enum GhosttyHoveredLink {
  /// libghostty's word stops at `:`, so `https` is judged with the rest of its address.
  private static let tokenSeparators: Set<Character> = [
    "\"", "'", "`", "(", ")", "[", "]", "{", "}", "<", ">", "|", "│", ",",
  ]
  private static let trailingPunctuation: Set<Character> = [".", ",", ";", ":", "!", "?"]

  /// `column` is where libghostty's word starts, counted in characters, which a
  /// wide character before it puts off by one; the nearest copy of the word wins.
  static func link(word: String, startingAt column: Int, in line: String) -> String? {
    // libghostty's word over a gap or a bracket is that run, which sits in no link.
    guard !word.allSatisfy(isSeparator) else { return nil }
    let characters = Array(line)
    let wordCharacters = Array(word)
    guard let start = nearestOccurrence(of: wordCharacters, in: characters, to: column) else {
      return link(inToken: word)
    }
    var lower = start
    while lower > 0, !isSeparator(characters[lower - 1]) { lower -= 1 }
    var upper = start + wordCharacters.count
    while upper < characters.count, !isSeparator(characters[upper]) { upper += 1 }
    return link(inToken: String(characters[lower..<upper]))
  }

  private static func nearestOccurrence(
    of word: [Character],
    in line: [Character],
    to column: Int,
  ) -> Int? {
    guard !word.isEmpty, word.count <= line.count else { return nil }
    return (0...(line.count - word.count))
      .filter { line[$0..<($0 + word.count)].elementsEqual(word) }
      .min { abs($0 - column) < abs($1 - column) }
  }

  private static func isSeparator(_ character: Character) -> Bool {
    character.isWhitespace || tokenSeparators.contains(character)
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
