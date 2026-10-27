/// The selected worktree's files holding every word of a query, best first, by
/// the byte search the Files panel's filter uses. See quick-switcher.md.
enum QuickSwitcherFileMatches {
  private static let inName = 100
  private static let startingName = 50

  /// Only the best `limit` are kept as the paths go by, as one letter in a
  /// large repository names nearly every path, too many to sort on each key.
  static func paths(
    _ query: QuickSwitcherQuery,
    in tree: FileTree,
    limit: Int,
  ) -> [String] {
    guard !query.isEmpty, limit > 0 else { return [] }
    let listing = tree.listing
    // An opened submodule's files are listed under its folder, its own repository's;
    // one never opened has none to leave out.
    let submoduleFolders = listing.readFolders.intersection(listing.repositories).map { $0 + "/" }
    var best = QuickSwitcherBestPaths(limit: limit)
    for (path, folded) in zip(listing.filePaths, listing.foldedFilePaths)
    where query.foldedWords.allSatisfy(folded.prefoldedContains) {
      let score = score(of: folded, for: query)
      // The exclusions after the cheap test, only for a path that would be kept.
      guard best.wouldKeep(path, score: score), !listing.ignoredFiles.contains(path),
        !listing.repositories.contains(path), !submoduleFolders.contains(where: path.hasPrefix),
        tree.isOpenable(path)
      else { continue }
      best.offer(path, score: score)
    }
    return best.paths
  }

  /// The characters of `name` each word was found at, as the substring the
  /// path matched by, so the bold letters are the ones that matched.
  static func nameOffsets(_ query: QuickSwitcherQuery, in name: String) -> Set<Int> {
    let folded = FoldedCharacters(name)
    let characters = folded.characters
    var offsets = Set<Int>()
    for word in query.words where word.count <= characters.count {
      let start = (0...(characters.count - word.count)).first { start in
        characters[start..<(start + word.count)].elementsEqual(word)
      }
      if let start {
        offsets.formUnion((start..<(start + word.count)).map { folded.sourceOffsets[$0] })
      }
    }
    return offsets
  }

  /// A word in the file's own name counts, and more at its start. The name's
  /// bytes are read in place, a copy per path costing one per key typed.
  private static func score(of folded: String, for query: QuickSwitcherQuery) -> Int {
    let bytes = folded.utf8
    let name =
      bytes.lastIndex(of: UInt8(ascii: "/")).map { bytes[bytes.index(after: $0)...] } ?? bytes[...]
    var score = 0
    for word in query.foldedWords where name.firstRange(of: word.utf8) != nil {
      score += name.starts(with: word.utf8) ? inName + startingName : inName
    }
    return score
  }
}
