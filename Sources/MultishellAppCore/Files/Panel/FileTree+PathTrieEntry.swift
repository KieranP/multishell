extension FileTree {
  /// One name in the tree being built, its children in the order the paths first
  /// named them; `build` turns these into nodes.
  struct PathTrieEntry {
    let name: Substring
    let path: String
    var children: [Int] = []
    var childByName: [Substring: Int] = [:]
    var endsAPath = false
  }
}
