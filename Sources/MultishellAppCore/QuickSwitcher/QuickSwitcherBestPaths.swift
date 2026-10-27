/// The highest-scoring paths offered, at most `limit`, best first and each
/// once; a tie goes to the shorter path, then path order.
struct QuickSwitcherBestPaths {
  private let limit: Int
  private var kept: [(score: Int, path: String)] = []

  var paths: [String] { kept.map(\.path) }

  init(limit: Int) {
    self.limit = limit
  }

  private static func ranks(
    _ lhs: (score: Int, path: String),
    above rhs: (score: Int, path: String),
  ) -> Bool {
    if lhs.score != rhs.score { return lhs.score > rhs.score }
    let lhsLength = lhs.path.utf8.count
    let rhsLength = rhs.path.utf8.count
    return lhsLength != rhsLength ? lhsLength < rhsLength : lhs.path < rhs.path
  }

  /// Whether `offer` would keep it, one comparison against the last kept.
  func wouldKeep(_ path: String, score: Int) -> Bool {
    guard kept.count == limit, let last = kept.last else { return true }
    return Self.ranks((score, path), above: last)
  }

  mutating func offer(_ path: String, score: Int) {
    guard wouldKeep(path, score: score) else { return }
    let index = kept.firstIndex { !Self.ranks($0, above: (score, path)) } ?? kept.count
    if index < kept.count, kept[index] == (score, path) { return }
    kept.insert((score, path), at: index)
    if kept.count > limit { kept.removeLast() }
  }
}
