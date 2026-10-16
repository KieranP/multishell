/// The words changed text differs from the text it replaced in, which the
/// view marks darker; see Docs/design/files.md.
enum WordDiff {
  enum Outcome: Equatable {
    /// In UTF-16 units of each text.
    case changed(old: [Range<Int>], new: [Range<Int>])
    /// Sharing under half the shorter text: marking nearly everything darker
    /// would tell nothing.
    case rewritten
    case tooLongToCompare
  }

  private enum TokenClass {
    case other
    case space
    case word
  }

  /// The work one comparison may do, in diagonals tried and tokens matched: a
  /// few hundred rewritten lines; past it the caller pairs line with line.
  static let comparedPairLimit = 1_000_000
  private static let minimumSharedFraction = 0.5
  /// Every run of spaces, a newline among them, is one token: a rewrap moving
  /// a break changes no word.
  private static let spaceTokenID = 0

  static func changedParts(from old: String, to new: String) -> Outcome {
    var budget = comparedPairLimit
    return changedParts(from: old, to: new, pairBudget: &budget)
  }

  /// Draws on a budget shared by several comparisons, which all stop once it
  /// is spent: a thousand long lines paired one by one took 4 s.
  static func changedParts(from old: String, to new: String, pairBudget: inout Int) -> Outcome {
    let (oldUnits, newUnits) = (Array(old.utf16), Array(new.utf16))
    let (oldTokens, newTokens) = (tokens(of: old), tokens(of: new))
    var ids: [ArraySlice<UInt16>: Int] = [:]
    let intern = { (units: [UInt16], token: (range: Range<Int>, isSpace: Bool)) -> Int in
      guard !token.isSpace else { return spaceTokenID }
      let key = units[token.range]
      if let id = ids[key] { return id }
      let id = ids.count + 1
      ids[key] = id
      return id
    }
    let oldIDs = oldTokens.map { intern(oldUnits, $0) }
    let newIDs = newTokens.map { intern(newUnits, $0) }
    let lonePunctuation = oldTokens.map { token in
      token.range.count == 1 && isPunctuation(oldUnits[token.range.lowerBound])
    }
    guard
      let kept = keptTokens(
        oldIDs,
        newIDs,
        lonePunctuation: lonePunctuation,
        pairBudget: &pairBudget,
      )
    else {
      return .tooLongToCompare
    }
    let shared = kept.old.reduce(0) { total, index in
      total + nonSpaceUnits(oldUnits[oldTokens[index].range])
    }
    let shorter = min(nonSpaceUnits(oldUnits[...]), nonSpaceUnits(newUnits[...]))
    guard shorter > 0, Double(shared) >= Double(shorter) * minimumSharedFraction else {
      return .rewritten
    }
    return .changed(
      old: merged(oldTokens.indices.filter { !kept.old.contains($0) }.map { oldTokens[$0].range }),
      new: merged(newTokens.indices.filter { !kept.new.contains($0) }.map { newTokens[$0].range }),
    )
  }

  /// The units that are not whitespace by the tokens' test, which a share of
  /// shared text is counted in; a surrogate half or a mark after a space is not.
  static func nonSpaceUnits(_ units: ArraySlice<UInt16>) -> Int {
    units.count { unit in
      guard let scalar = Unicode.Scalar(unit) else { return true }
      return tokenClass(of: scalar).0 != .space
    }
  }

  /// Runs of letters, digits and `_`, runs of spaces, and each other
  /// character alone; a combining mark stays with what it marks.
  private static func tokens(of text: String) -> [(range: Range<Int>, isSpace: Bool)] {
    var tokens: [(range: Range<Int>, isSpace: Bool)] = []
    var start = 0
    var offset = 0
    var current: TokenClass?
    for scalar in text.unicodeScalars {
      let width = scalar.utf16.count
      let (kind, joinsPrevious) = tokenClass(of: scalar)
      if !(joinsPrevious && current != nil), kind != current || kind == .other {
        if offset > start, let current {
          tokens.append((start..<offset, current == .space))
        }
        start = offset
        current = kind
      }
      offset += width
    }
    if offset > start, let current { tokens.append((start..<offset, current == .space)) }
    return tokens
  }

  /// ASCII answered by value: looking up a scalar's properties took 140 ns,
  /// most of a long line's tokenising.
  private static func tokenClass(of scalar: Unicode.Scalar) -> (TokenClass, joinsPrevious: Bool) {
    let value = scalar.value
    if value < 0x80 {
      switch value {
      case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x5F: return (.word, false)
      case 0x09, 0x0A, 0x0D, 0x20: return (.space, false)
      default: return (.other, false)
      }
    }
    let properties = scalar.properties
    let joins = properties.isGraphemeExtend || scalar == "\u{200D}"
    if properties.isAlphabetic || properties.numericType != nil { return (.word, joins) }
    return (properties.isWhitespace ? .space : .other, joins)
  }

  /// The tokens both texts keep, by index: the shared ends, then a longest
  /// common subsequence of what lies between; `nil` past the pair limit.
  private static func keptTokens(
    _ old: [Int],
    _ new: [Int],
    lonePunctuation: [Bool],
    pairBudget: inout Int,
  ) -> (old: Set<Int>, new: Set<Int>)? {
    var prefix = 0
    while prefix < old.count, prefix < new.count, old[prefix] == new[prefix] { prefix += 1 }
    var suffix = 0
    while suffix < old.count - prefix, suffix < new.count - prefix,
      old[old.count - 1 - suffix] == new[new.count - 1 - suffix]
    {
      suffix += 1
    }
    var keptOld = Set(0..<prefix).union((old.count - suffix)..<old.count)
    var keptNew = Set(0..<prefix).union((new.count - suffix)..<new.count)
    let oldMiddle = Array(old[prefix..<(old.count - suffix)])
    let newMiddle = Array(new[prefix..<(new.count - suffix)])
    guard let common = shortestEditMatches(oldMiddle, newMiddle, pairBudget: &pairBudget) else {
      return nil
    }
    for (pair, (oldIndex, newIndex)) in common.enumerated() {
      // A lone `.` matched between changed words splits one change in two.
      let before = pair > 0 ? common[pair - 1] : nil
      let after = pair + 1 < common.count ? common[pair + 1] : nil
      let isIsolatedNew =
        (before.map { $0.1 != newIndex - 1 } ?? (newIndex > 0))
        && (after.map { $0.1 != newIndex + 1 } ?? (newIndex < newMiddle.count - 1))
      let isIsolatedOld =
        (before.map { $0.0 != oldIndex - 1 } ?? (oldIndex > 0))
        && (after.map { $0.0 != oldIndex + 1 } ?? (oldIndex < oldMiddle.count - 1))
      if lonePunctuation[prefix + oldIndex], isIsolatedNew || isIsolatedOld { continue }
      keptOld.insert(prefix + oldIndex)
      keptNew.insert(prefix + newIndex)
    }
    return (keptOld, keptNew)
  }

  /// The tokens matched by a shortest edit script, Myers' O(ND) diff, as index
  /// pairs: a few edits in long lines cost little, where a table cost N×M.
  private static func shortestEditMatches(
    _ old: [Int],
    _ new: [Int],
    pairBudget: inout Int,
  ) -> [(Int, Int)]? {
    let (oldCount, newCount) = (old.count, new.count)
    guard oldCount > 0, newCount > 0 else { return [] }
    let offset = oldCount + newCount + 1
    var furthest = [Int](repeating: 0, count: 2 * offset + 1)
    // Each step's window of diagonals, as the step before left them, copied
    // out: a slice kept `furthest` shared, so each write copied all of it.
    var trace: [[Int]] = []
    for edits in 0...(oldCount + newCount) {
      trace.append(Array(furthest[(offset - edits - 1)...(offset + edits + 1)]))
      for diagonal in stride(from: -edits, through: edits, by: 2) {
        let down =
          diagonal == -edits
          || (diagonal != edits
            && furthest[offset + diagonal - 1] < furthest[offset + diagonal + 1])
        var x = down ? furthest[offset + diagonal + 1] : furthest[offset + diagonal - 1] + 1
        var y = x - diagonal
        var work = 1
        while x < oldCount, y < newCount, old[x] == new[y] {
          x += 1
          y += 1
          work += 1
        }
        guard work <= pairBudget else { return nil }
        pairBudget -= work
        furthest[offset + diagonal] = x
        if x >= oldCount, y >= newCount {
          return matches(through: trace, endingAt: (oldCount, newCount))
        }
      }
    }
    return []
  }

  /// Walks the script back from its end, keeping each diagonal step.
  private static func matches(
    through trace: [[Int]],
    endingAt end: (Int, Int),
  ) -> [(Int, Int)] {
    var (x, y) = end
    var pairs: [(Int, Int)] = []
    for edits in stride(from: trace.count - 1, through: 0, by: -1) {
      let window = trace[edits]
      let furthest = { (diagonal: Int) in window[diagonal + edits + 1] }
      let diagonal = x - y
      let down =
        diagonal == -edits
        || (diagonal != edits && furthest(diagonal - 1) < furthest(diagonal + 1))
      let previousDiagonal = down ? diagonal + 1 : diagonal - 1
      let previousX = edits == 0 ? 0 : furthest(previousDiagonal)
      let previousY = edits == 0 ? 0 : previousX - previousDiagonal
      while x > previousX, y > previousY {
        x -= 1
        y -= 1
        pairs.append((x, y))
      }
      (x, y) = (previousX, previousY)
    }
    return pairs.reversed()
  }

  private static func isPunctuation(_ unit: UInt16) -> Bool {
    Unicode.Scalar(unit).map { Character($0).isPunctuation } ?? false
  }

  /// Touching ranges as one, so a changed run is one mark.
  private static func merged(_ ranges: [Range<Int>]) -> [Range<Int>] {
    var merged: [Range<Int>] = []
    for range in ranges {
      if let last = merged.last, last.upperBound == range.lowerBound {
        merged[merged.count - 1] = last.lowerBound..<range.upperBound
      } else {
        merged.append(range)
      }
    }
    return merged
  }
}
