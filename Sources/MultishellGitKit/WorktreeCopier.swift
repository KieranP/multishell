import Foundation

/// Copies the files a project lists into each new worktree, for what git
/// does not carry across: `.env`, a local config, a build cache.
///
/// One path per line, relative to the repository root. A blank line, and a
/// line starting with `#`, is skipped, as is a path the repository does not
/// have: a list naming `.env` is right for a checkout that has one and
/// should not fail the ones that do not. A destination that already exists
/// is left alone, since git put it there and a tracked file beats a copy.
///
/// A component may be a pattern: `*` for any run of characters and `?` for
/// one, neither crossing a `/`. `.env.*` is the reason it is here. A
/// pattern matches a name starting with `.` only when it spells the dot,
/// as a shell does, so `*` does not sweep up `.git`.
public struct WorktreeCopier: Sendable {
  public init() {}

  /// The paths in a list, in order, without blanks, comments or repeats.
  /// Nothing here judges the shape of a path: `copy` decides what is in
  /// reach against the disk, which is the only place that can say.
  public static func paths(in list: String) -> [String] {
    var seen: Set<String> = []
    return list.split(whereSeparator: \.isNewline).compactMap { line in
      let path = line.trimmingCharacters(in: .whitespaces)
      guard !path.isEmpty, !path.hasPrefix("#") else { return nil }
      return seen.insert(path).inserted ? path : nil
    }
  }

  /// Copies each listed path from `repository` into `worktree`, making the
  /// parent directories a nested path needs. Copies everything it can and
  /// then throws `WorktreeCopyFailure` naming what it could not, so one
  /// unreadable file does not cost the rest of the list.
  public func copy(_ list: String, from repository: URL, to worktree: URL) throws {
    let manager = FileManager.default
    let repositoryBase = repository.resolvingSymlinksInPath()
    let worktreeBase = worktree.resolvingSymlinksInPath()
    var failures: [WorktreeCopyFailure.Item] = []

    for path in Self.paths(in: list).flatMap({ Self.expand($0, in: repository) }) {
      let source = repository.appendingPathComponent(path)
      let destination = worktree.appendingPathComponent(path)
      // A path the repository does not have is the quiet case and comes
      // first, so `.env` on a checkout without one is not an escape.
      guard manager.fileExists(atPath: source.path) else { continue }
      // The folders on the way to each end, as they are on disk. This is
      // the whole of the containment check: `..` resolves here, a leading
      // `/` or `~` lands under the repository and is harmless, and a
      // folder that is a symlink is caught, which spelling cannot do.
      //
      // Before the destination is tested for being there already: the two
      // ends of an escaping path often resolve to the same file, and that
      // test would take it for something git had checked out and say
      // nothing.
      guard Self.isInside(repositoryBase, source.deletingLastPathComponent()),
        Self.isInside(worktreeBase, Self.deepestExistingAncestor(of: destination))
      else {
        failures.append(WorktreeCopyFailure.Item(path: path, underlying: WorktreeCopyEscape()))
        continue
      }
      guard !manager.fileExists(atPath: destination.path) else { continue }
      do {
        try manager.createDirectory(
          at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try manager.copyItem(at: source, to: destination)
      } catch {
        failures.append(WorktreeCopyFailure.Item(path: path, underlying: error))
      }
    }
    guard failures.isEmpty else { throw WorktreeCopyFailure(items: failures) }
  }

  /// The paths a listed one stands for. A path with no pattern in it is
  /// itself, untouched and never looked up, so what happens to a plain
  /// path does not depend on a directory being readable. A pattern that
  /// matches nothing yields nothing, the same as naming a file that is not
  /// there. Sorted, so a copy of many files goes in a stated order.
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

  /// Whether one name matches one pattern component. `*` and `?` only:
  /// a bracket expression is more than a copy list needs and is taken
  /// literally.
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

  /// Whether `url`, symlinks resolved, is `base` or something under it.
  /// Compared by path component, so `/a/bc` is not under `/a/b`.
  private static func isInside(_ base: URL, _ url: URL) -> Bool {
    let root = base.standardizedFileURL.pathComponents
    let leaf = url.resolvingSymlinksInPath().standardizedFileURL.pathComponents
    return leaf.count >= root.count && Array(leaf.prefix(root.count)) == root
  }

  /// The nearest folder on the way to `url` that is already there.
  /// Resolving `url` itself would say nothing: a path whose tail does not
  /// exist yet is left alone, symlinked folders and all. Only what is
  /// below this is created, and what is created is never a symlink, so
  /// this is the whole of what the copy can be diverted through.
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

/// Raised when the copy into a new worktree could not finish. The worktree
/// exists and everything else on the list is in it; only these paths are
/// missing.
public struct WorktreeCopyFailure: Error, CustomStringConvertible {
  public struct Item: Sendable {
    public let path: String
    public let underlying: any Error

    public init(path: String, underlying: any Error) {
      self.path = path
      self.underlying = underlying
    }
  }

  public let items: [Item]

  public init(items: [Item]) {
    self.items = items
  }

  public var description: String {
    items.map { "\($0.path): \($0.underlying.localizedDescription)" }.joined(separator: "\n")
  }
}

/// A listed path that leads out of the repository or the worktree, by
/// `..` or through a folder that is a symlink. `LocalizedError`, so it
/// reads as a sentence in the alert beside the file system's own reasons.
public struct WorktreeCopyEscape: LocalizedError {
  public init() {}

  public var errorDescription: String? {
    "It leads outside the repository or the worktree."
  }
}
