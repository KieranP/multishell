import Foundation

/// Building a worktree's tree from its paths, once per listing.
extension FileTree {
  /// The order rows sort in: folders first, then by name as Finder does.
  private static func sorted(_ nodes: [Node]) -> [Node] {
    nodes.sorted { first, second in
      if first.isFolder != second.isFolder { return first.isFolder }
      return first.name.localizedStandardCompare(second.name) == .orderedAscending
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
    return nodes(below: "", from: paths.map { $0.split(separator: "/") }, depth: 0, marks: marks)
  }

  /// Each path split once and grouped by its part at `depth`, so a level is
  /// one pass over the paths below it and the tree builds in linear time.
  private static func nodes(
    below parentPath: String,
    from paths: [[Substring]],
    depth: Int,
    marks: NodeMarks,
  ) -> [Node] {
    var names: [Substring] = []
    var pathsBelow: [Substring: [[Substring]]] = [:]
    for parts in paths where parts.count > depth {
      let name = parts[depth]
      if pathsBelow[name] == nil {
        names.append(name)
        pathsBelow[name] = []
      }
      if parts.count > depth + 1 { pathsBelow[name, default: []].append(parts) }
    }
    return sorted(
      names.map { part in
        let name = String(part)
        let path = parentPath.isEmpty ? name : parentPath + "/" + name
        let below = pathsBelow[part] ?? []
        return Node(
          name: name,
          path: path,
          children: below.isEmpty
            ? [] : nodes(below: path, from: below, depth: depth + 1, marks: marks),
          isFolder: !below.isEmpty || marks.folders.contains(path),
          isRepository: marks.repositories.contains(path),
          isIgnored: marks.ignored.contains(path),
        )
      }
    )
  }
}
