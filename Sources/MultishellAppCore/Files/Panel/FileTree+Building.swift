import Foundation
import MultishellCore

/// Building a worktree's tree from its paths, once per listing.
extension FileTree {
  /// The order siblings sort in: folders first, then by name as Finder does.
  /// The All changes tab lists its files in it too.
  static func sortsBefore(
    _ first: some StringProtocol,
    isFolder firstIsFolder: Bool,
    _ second: some StringProtocol,
    isFolder secondIsFolder: Bool,
  ) -> Bool {
    if firstIsFolder != secondIsFolder { return firstIsFolder }
    return first.localizedStandardCompare(second) == .orderedAscending
  }

  private static func sorted(_ nodes: [Node]) -> [Node] {
    nodes.sorted { first, second in
      sortsBefore(first.name, isFolder: first.isFolder, second.name, isFolder: second.isFolder)
    }
  }

  static func build(
    _ paths: [String],
    folders: Set<String>,
    repositories: Set<String>,
    ignored: Set<String>,
  ) -> [Node] {
    let marks = NodeMarks(
      folders: folders,
      repositories: repositories,
      ignored: ignored,
    )
    let entries = trie(of: paths)
    // Bottom up without recursion: a path from a Linux push can nest past what
    // a Dispatch thread's 512 KiB stack holds. A child's index exceeds its parent's.
    var built = [[Node]](repeating: [], count: entries.count)
    for index in entries.indices.dropFirst().reversed() {
      let entry = entries[index]
      let children = sorted(entry.children.flatMap { built[$0] })
      for child in entry.children { built[child] = [] }
      built[index] = nodes(for: entry, children: children, marks: marks)
    }
    return sorted(entries[0].children.flatMap { built[$0] })
  }

  /// Each path walked once from the root at index 0, so the tree builds in linear time.
  private static func trie(of paths: [String]) -> [PathTrieEntry] {
    var entries = [PathTrieEntry(name: "", path: "")]
    for path in paths {
      var parent = 0
      for part in path.slashSeparatedParts {
        if let child = entries[parent].childByName[part] {
          parent = child
          continue
        }
        let parentPath = entries[parent].path
        let name = String(part)
        let child = entries.count
        entries.append(
          PathTrieEntry(name: part, path: parentPath.isEmpty ? name : parentPath + "/" + name)
        )
        entries[parent].children.append(child)
        entries[parent].childByName[part] = child
        parent = child
      }
      if parent != 0 { entries[parent].endsAPath = true }
    }
    return entries
  }

  private static func nodes(
    for entry: PathTrieEntry,
    children: [Node],
    marks: NodeMarks,
  ) -> [Node] {
    let hasChildren = !entry.children.isEmpty
    let node = Node(
      name: String(entry.name),
      path: entry.path,
      children: children,
      isFolder: hasChildren || marks.folders.contains(entry.path),
      isRepository: marks.repositories.contains(entry.path),
      isIgnored: marks.ignored.contains(entry.path),
    )
    // A file replaced by a folder of its name, or the reverse: both are listed.
    guard hasChildren, entry.endsAPath, !marks.folders.contains(entry.path) else {
      return [node]
    }
    let file = Node(
      name: String(entry.name),
      path: entry.path,
      children: [],
      isFolder: false,
      isRepository: false,
      isIgnored: marks.ignored.contains(entry.path),
    )
    return [node, file]
  }
}
