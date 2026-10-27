/// How well a query names a row, each word found in order through the title
/// or starting a word of its location. See Docs/design/quick-switcher.md.
struct QuickSwitcherMatch: Equatable, Sendable {
  private static let perCharacter = 10
  private static let atStart = 60
  private static let atWordStart = 50
  private static let followingOn = 40
  private static let gapOpening = 15
  /// The most a gap before a character costs, so one long name is not sunk.
  private static let largestGapCost = 30
  /// A title match outweighs a location's, the title being what the row is.
  private static let titleWeight = 2
  private static let locationPerCharacter = 20

  let score: Int
  /// The title's characters the query matched, by offset.
  let titleOffsets: Set<Int>

  init?(_ query: QuickSwitcherQuery, title: String, location: String) {
    let folded = FoldedCharacters(title)
    var locationWords: [[String]]?
    var score = 0
    var offsets = Set<Int>()
    for word in query.words {
      let found = Self.subsequence(word, in: folded.characters)
      let titleScore = found.map { $0.score * Self.titleWeight }
      let locationScore = word.count * Self.locationPerCharacter
      // Letters scattered through the title can score below the word named
      // outright where the row is, so the location is asked then.
      if (titleScore ?? .min) < locationScore {
        let words = locationWords ?? Self.words(of: location)
        locationWords = words
        if words.contains(where: { $0.starts(with: word) }) {
          score += locationScore
          continue
        }
      }
      guard let found, let titleScore else { return nil }
      score += titleScore
      offsets.formUnion(found.offsets.map { folded.sourceOffsets[$0] })
    }
    self.score = score
    titleOffsets = offsets
  }

  /// Split where a word starts, and also whole between spaces, so `api` and
  /// `billing-api` both find `billing-api`.
  private static func words(of location: String) -> [[String]] {
    let folded = location.foldedForMatching.map(String.init)
    var words: [[String]] = []
    var current: [String] = []
    var spaced: [String] = []
    for character in folded {
      if character.allSatisfy(\.isWhitespace) || character == QuickSwitcherItem.pathStep {
        words.append(current)
        words.append(spaced)
        current = []
        spaced = []
      } else if isSeparator(character) {
        words.append(current)
        current = []
        spaced.append(character)
      } else {
        current.append(character)
        spaced.append(character)
      }
    }
    words.append(current)
    words.append(spaced)
    return words.filter { !$0.isEmpty }
  }

  /// The best of the greedy matches from each place the first letter is, as a
  /// path names its project first. Runs score as fzf's do; quick-switcher.md.
  private static func subsequence(
    _ word: [String],
    in title: [String],
  ) -> (score: Int, offsets: [Int])? {
    guard let first = word.first else { return nil }
    var best: (score: Int, offsets: [Int])?
    for start in title.indices where title[start] == first {
      guard
        let found = preferring(wordStarts: true, word, in: title, startingAt: start)
          ?? preferring(wordStarts: false, word, in: title, startingAt: start)
      else { break }
      if found.score > best?.score ?? .min { best = found }
    }
    return best
  }

  /// Greedy from `start`, a following character first, then a word's start;
  /// plain greedy where that strands the rest.
  private static func preferring(
    wordStarts: Bool,
    _ word: [String],
    in title: [String],
    startingAt start: Int,
  ) -> (score: Int, offsets: [Int])? {
    var offsets: [Int] = []
    var score = 0
    var from = start
    var last: Int?
    var runBonus = 0
    for character in word {
      var position: Int?
      if last == nil {
        position = start
      } else if let last, last + 1 < title.count, title[last + 1] == character {
        position = last + 1
      } else if wordStarts {
        position = (from..<title.count).first { offset in
          title[offset] == character && startsWord(at: offset, in: title)
        }
      }
      guard
        let found = position ?? (from..<title.count).first(where: { title[$0] == character })
      else { return nil }
      if let last, found == last + 1 {
        runBonus = max(runBonus, followingOn)
      } else {
        runBonus = found == 0 ? atStart : startsWord(at: found, in: title) ? atWordStart : 0
        if last != nil { score -= min(largestGapCost, gapOpening + found - from) }
      }
      score += perCharacter + runBonus
      offsets.append(found)
      last = found
      from = found + 1
    }
    return (score, offsets)
  }

  private static func startsWord(at offset: Int, in title: [String]) -> Bool {
    offset == 0 || isSeparator(title[offset - 1]) || title[offset - 1].allSatisfy(\.isWhitespace)
  }

  private static func isSeparator(_ character: String) -> Bool {
    ["-", "_", "/", ".", ":", "(", ")"].contains(character)
  }
}
