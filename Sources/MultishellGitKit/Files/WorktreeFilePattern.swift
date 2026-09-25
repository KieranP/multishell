import Foundation

/// A list entry's `*` and `?`, matched one path component at a time against
/// what is on disk, as a shell would.
enum WorktreeFilePattern {
  /// The paths a listed one stands for. One with no pattern is itself, never
  /// looked up; a pattern matching nothing yields nothing. Sorted.
  static func expand(_ path: String, in base: URL) -> [String] {
    let components = path.split(separator: "/").map(String.init)
    guard components.contains(where: isPattern) else { return [path] }
    var expanded: [String] = [""]
    for component in components {
      guard isPattern(component) else {
        expanded = expanded.map { $0.isEmpty ? component : "\($0)/\(component)" }
        continue
      }
      expanded = expanded.flatMap { prefix -> [String] in
        let directory = prefix.isEmpty ? base : base.appendingPathComponent(prefix)
        let names =
          (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.filter { matches($0, pattern: component) }.sorted()
          .map { prefix.isEmpty ? $0 : "\(prefix)/\($0)" }
      }
    }
    return expanded
  }

  /// Whether one name matches one pattern component. `*` and `?` only; a
  /// bracket expression is taken literally.
  static func matches(_ name: String, pattern: String) -> Bool {
    // As a shell does: a name a person meant to hide is matched only by a
    // pattern that says the dot, or `*` would take `.git` with it.
    guard !name.hasPrefix(".") || pattern.hasPrefix(".") else { return false }
    let name = Array(name)
    let pattern = Array(pattern)
    var nameIndex = 0
    var patternIndex = 0
    var lastStar = -1
    var resumeAt = 0
    while nameIndex < name.count {
      if patternIndex < pattern.count,
        pattern[patternIndex] == "?" || pattern[patternIndex] == name[nameIndex]
      {
        nameIndex += 1
        patternIndex += 1
      } else if patternIndex < pattern.count, pattern[patternIndex] == "*" {
        lastStar = patternIndex
        patternIndex += 1
        resumeAt = nameIndex
      } else if lastStar >= 0 {
        // Backtrack: the last `*` takes one more character.
        patternIndex = lastStar + 1
        resumeAt += 1
        nameIndex = resumeAt
      } else {
        return false
      }
    }
    return pattern[patternIndex...].allSatisfy { $0 == "*" }
  }

  private static func isPattern(_ component: String) -> Bool {
    component.contains("*") || component.contains("?")
  }
}
