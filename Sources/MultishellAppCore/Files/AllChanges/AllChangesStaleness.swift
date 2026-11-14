/// Which files an All changes tab's next read reads again rather than keeps.
enum AllChangesStaleness: Equatable, Sendable {
  /// A git change, a new scope, algorithm or base: every diff may have moved.
  case everything
  /// Files an event or the status read moved; the rest keep their rows.
  case paths(Set<String>)

  static let nothing = Self.paths([])

  func contains(_ path: String) -> Bool {
    switch self {
    case .everything: true
    case .paths(let paths): paths.contains(path)
    }
  }

  func adding(_ other: Self) -> Self {
    switch (self, other) {
    case (.everything, _), (_, .everything): .everything
    case (.paths(let paths), .paths(let others)): .paths(paths.union(others))
    }
  }
}
