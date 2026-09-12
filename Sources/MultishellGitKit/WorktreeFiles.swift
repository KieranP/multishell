import Foundation

/// Puts a project's listed files into each new worktree, for what git does
/// not carry. One path per line, `*` and `?` allowed; see hooks.md.
public struct WorktreeFiles: Sendable {
  public init() {}

  /// The paths in a list, without blanks, comments or repeats. `place`
  /// judges what is in reach, against the disk.
  public static func paths(in list: String) -> [String] {
    var seen: Set<String> = []
    return list.split(whereSeparator: \.isNewline).compactMap { line in
      let path = line.trimmingCharacters(in: .whitespaces)
      guard !path.isEmpty, !path.hasPrefix("#") else { return nil }
      return seen.insert(path).inserted ? path : nil
    }
  }

  /// Links or copies each listed path, placing all it can before throwing.
  /// `isStopped` is asked per path, there being no process to signal.
  public func place(
    _ list: String, as placement: WorktreePlacement, from repository: URL, to worktree: URL,
    isStopped: @Sendable () -> Bool = { false }
  ) throws {
    let manager = FileManager.default
    let repositoryBase = repository.resolvingSymlinksInPath()
    let worktreeBase = worktree.resolvingSymlinksInPath()
    var failures: [WorktreeFileFailure.Item] = []

    for path in Self.paths(in: list).flatMap({ Self.expand($0, in: repository) }) {
      guard !isStopped() else { throw WorktreeFilesStopped(failures: failures) }
      let source = repository.appendingPathComponent(path)
      let destination = worktree.appendingPathComponent(path)
      // A path the repository does not have is the quiet case and comes
      // first, so `.env` on a checkout without one is not an escape.
      guard manager.fileExists(atPath: source.path) else { continue }
      // The folders on the way to each end, as on disk: the whole
      // containment check, and before the destination is tested.
      guard Self.isInside(repositoryBase, source.deletingLastPathComponent()),
        Self.isInside(worktreeBase, Self.deepestExistingAncestor(of: destination))
      else {
        failures.append(WorktreeFileFailure.Item(path: path, underlying: WorktreeFileEscape()))
        continue
      }
      guard !Self.isPresent(destination) else { continue }
      do {
        try manager.createDirectory(
          at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        switch placement {
        case .link:
          // The repository's path unresolved, so the link reads as the
          // checkout the user sees. Absolute, as git records one.
          try manager.createSymbolicLink(at: destination, withDestinationURL: source)
        case .copy:
          try manager.copyItem(at: source, to: destination)
        }
      } catch {
        failures.append(WorktreeFileFailure.Item(path: path, underlying: error))
      }
    }
    guard failures.isEmpty else { throw WorktreeFileFailure(placement: placement, items: failures) }
  }

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

  /// Whether anything is at `url`, a symlink included, without asking where
  /// it leads: the question is what is in the way, not what resolves.
  private static func isPresent(_ url: URL) -> Bool {
    (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
  }

  private static func isPattern(_ component: String) -> Bool {
    component.contains("*") || component.contains("?")
  }

  /// Whether `url`, symlinks resolved, is `base` or something under it.
  /// Compared by path component, so `/a/bc` is not under `/a/b`.
  private static func isInside(_ base: URL, _ url: URL) -> Bool {
    let root = base.standardizedFileURL.pathComponents
    let leaf = url.resolvingSymlinksInPath().standardizedFileURL.pathComponents
    return leaf.count >= root.count && Array(leaf.prefix(root.count)) == root
  }

  /// The nearest folder on the way to `url` already there. Resolving `url`
  /// says nothing, a path whose tail is missing being left alone.
  private static func deepestExistingAncestor(of url: URL) -> URL {
    var current = url.deletingLastPathComponent()
    while current.pathComponents.count > 1,
      !FileManager.default.fileExists(atPath: current.path)
    {
      current = current.deletingLastPathComponent()
    }
    return current
  }
}
