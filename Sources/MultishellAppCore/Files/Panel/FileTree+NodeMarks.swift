extension FileTree {
  /// What a path is beside its place in the tree, decided when its node is made.
  struct NodeMarks {
    let folders: Set<String>
    let repositories: Set<String>
    let ignored: Set<String>
  }
}
