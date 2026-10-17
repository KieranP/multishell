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

  /// Ignored files, and folders whose entries are not listed until opened.
  static func ignoredFilesAndFolders(
    _ sources: FileTreeSources
  ) -> (files: [String], folders: [String]) {
    var files: [String] = []
    var folders: [String] = []
    for entry in sources.ignoredEntries {
      if entry.hasSuffix("/") {
        folders.append(String(entry.dropLast()))
      } else {
        files.append(entry)
      }
    }
    for (folder, entries) in sources.ignoredFolderEntries {
      for entry in entries {
        let path = folder + "/" + entry.name
        if entry.isFolder { folders.append(path) } else { files.append(path) }
      }
    }
    return (files, folders)
  }

  static func build(
    _ paths: [String],
    folders: Set<String>,
    repositories: Set<String>,
    ignored: Set<String>,
  ) -> [Node] {
    var root = Node(
      name: "",
      path: "",
      children: [],
      isFolder: true,
      isRepository: false,
      isIgnored: false,
    )
    var index: [String: [Int]] = ["": []]
    let marks = NodeMarks(
      folders: folders,
      repositories: repositories,
      ignored: ignored,
    )
    for path in paths { insert(path, into: &root, index: &index, marks: marks) }
    return sortedTree(root).children
  }

  /// Walks down by each folder's position among its parent's children,
  /// kept in `index`, so a deep tree of many files builds in linear time.
  private static func insert(
    _ path: String,
    into root: inout Node,
    index: inout [String: [Int]],
    marks: NodeMarks,
  ) {
    let parts = path.split(separator: "/").map(String.init)
    var trail: [Int] = []
    var prefix = ""
    for (depth, part) in parts.enumerated() {
      let isLast = depth == parts.count - 1
      let childPath = prefix.isEmpty ? part : prefix + "/" + part
      if let existing = index[childPath] {
        trail = existing
      } else {
        let node = Node(
          name: part,
          path: childPath,
          children: [],
          isFolder: !isLast || marks.folders.contains(childPath),
          isRepository: marks.repositories.contains(childPath),
          isIgnored: marks.ignored.contains(childPath),
        )
        let position = mutate(&root, at: trail) { parent in
          parent.children.append(node)
          return parent.children.count - 1
        }
        trail.append(position)
        index[childPath] = trail
      }
      if !isLast { mutate(&root, at: trail) { $0.isFolder = true } }
      prefix = childPath
    }
  }

  @discardableResult
  private static func mutate<Result>(
    _ node: inout Node,
    at trail: [Int],
    _ change: (inout Node) -> Result,
  ) -> Result {
    guard let first = trail.first else { return change(&node) }
    return mutate(&node.children[first], at: Array(trail.dropFirst()), change)
  }

  private static func sortedTree(_ node: Node) -> Node {
    var sortedNode = node
    sortedNode.children = sorted(node.children.map(sortedTree))
    return sortedNode
  }
}
