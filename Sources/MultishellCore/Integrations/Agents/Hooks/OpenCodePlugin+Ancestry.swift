extension OpenCodePlugin {
  /// A session's parent, its parent's parent and on up, walked at each use, as a
  /// parent can be learned after its child; a cycle stops where it closes.
  static let ancestry = """
    const ancestorsOf = (id, parentOf) => {
      const line = []
      const seen = new Set([id])
      for (let parent = parentOf(id); parent && !seen.has(parent); parent = parentOf(parent)) {
        seen.add(parent)
        line.push(parent)
      }
      return line
    }
    const topLevelOf = (id, parentOf) => ancestorsOf(id, parentOf).pop() || id

    """
}
