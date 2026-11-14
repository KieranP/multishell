import Foundation
import MultishellCore
import MultishellGitKit

/// The files the All changes tab lists, in the Changes list's order: depth
/// first, folders before files, names as Finder sorts them.
enum AllChangesOrder {
  /// One entry a path, a path listed twice combined as the Changes list counts
  /// it; a nested repository's entry, which ends in `/`, is left out.
  static func files(of changes: [StatusChange]) -> [AllChangesFileChange] {
    var byPath: [String: AllChangesFileChange] = [:]
    for change in changes where !change.path.hasSuffix("/") {
      let counts = FileLineCounts(change.lines)
      guard let listed = byPath[change.path] else {
        byPath[change.path] = AllChangesFileChange(
          path: change.path,
          kind: change.kind,
          lineCounts: counts,
        )
        continue
      }
      byPath[change.path] = AllChangesFileChange(
        path: change.path,
        kind: listed.kind.combined(with: change.kind),
        lineCounts: listed.lineCounts.map { total in counts.map { total + $0 } ?? total }
          ?? counts,
      )
    }
    let parts = byPath.keys.map { ($0, $0.slashSeparatedParts) }
    return parts.sorted { isBefore($0.1, $1.1) }.compactMap { byPath[$0.0] }
  }

  /// Where the two paths first part ways, a folder goes before a file and
  /// otherwise the names decide, as the tree's siblings sort.
  private static func isBefore(_ first: [Substring], _ second: [Substring]) -> Bool {
    for index in 0..<min(first.count, second.count) {
      let firstIsFolder = index < first.count - 1
      let secondIsFolder = index < second.count - 1
      guard first[index] != second[index] || firstIsFolder != secondIsFolder else { continue }
      return FileTree.sortsBefore(
        first[index],
        isFolder: firstIsFolder,
        second[index],
        isFolder: secondIsFolder,
      )
    }
    return first.count > second.count
  }
}
