/// Marks the changes on disk the index holds too, matched across the two diffs
/// against `HEAD`; see Docs/design/files.md for why one algorithm diffs both.
enum StagedChangeMarker {
  /// Where an addition sits: the `HEAD` line it comes before, and its text.
  private struct Addition: Hashable {
    let beforeOldLine: Int
    let text: String
  }

  static func marking(_ working: [DiffLine], stagedIn staged: [DiffLine]) -> [DiffLine] {
    let stagedRemovals = Set(staged.filter { $0.kind == .removed }.compactMap(\.oldNumber))
    var stagedAdditions: [Addition: Int] = [:]
    for addition in additions(in: staged) { stagedAdditions[addition, default: 0] += 1 }
    var marked: [DiffLine] = []
    marked.reserveCapacity(working.count)
    var nextOldLine = 1
    for line in working {
      switch line.kind {
      case .context, .padding:
        nextOldLine = (line.oldNumber ?? nextOldLine) + 1
        marked.append(line)

      case .removed:
        nextOldLine = (line.oldNumber ?? nextOldLine) + 1
        let isStaged = line.oldNumber.map(stagedRemovals.contains) ?? false
        marked.append(isStaged ? line.staged() : line)

      case .added:
        let addition = Addition(beforeOldLine: nextOldLine, text: line.text)
        if let count = stagedAdditions[addition], count > 0 {
          stagedAdditions[addition] = count - 1
          marked.append(line.staged())
        } else {
          marked.append(line)
        }
      }
    }
    return marked
  }

  private static func additions(in lines: [DiffLine]) -> [Addition] {
    var nextOldLine = 1
    var found: [Addition] = []
    for line in lines {
      if line.kind == .added {
        found.append(Addition(beforeOldLine: nextOldLine, text: line.text))
      } else {
        nextOldLine = (line.oldNumber ?? nextOldLine) + 1
      }
    }
    return found
  }
}
