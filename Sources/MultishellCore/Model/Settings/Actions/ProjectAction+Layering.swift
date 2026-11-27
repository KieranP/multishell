extension ProjectAction {
  /// The user's own in the Actions page's order, then the file's others in its
  /// order; a repeated name keeps its first, an own action standing in for the file's.
  static func layered(own: [ProjectAction], over shared: [ProjectAction]) -> [ProjectAction] {
    uniquelyNamed(own + shared)
  }

  static func uniquelyNamed(_ actions: [ProjectAction]) -> [ProjectAction] {
    var seen = Set<String>()
    return actions.filter { seen.insert($0.name).inserted }
  }
}
