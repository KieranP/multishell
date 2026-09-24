import Foundation
import MultishellCore

/// Puts a project's listed files into each new worktree, for what git does
/// not carry. One path per line, `*` and `?` allowed; see hooks.md.
public struct WorktreeFiles: Sendable {
  public init() {}

  /// The paths in a list, without blanks, comments or repeats. `place`
  /// judges what is in reach, against the disk.
  public static func paths(in list: String) -> [String] {
    var seen: Set<String> = []
    return LineList.entries(in: list).filter { seen.insert($0).inserted }
  }

  /// Links or copies each listed path, placing all it can before throwing, and
  /// returns a user's own entries that name somewhere else; see hooks.md.
  @discardableResult
  public func place(
    _ list: String, as placement: WorktreePlacement, from repository: URL, to worktree: URL,
    heldToRepository: Bool = true, isStopped: @Sendable () -> Bool = { false }
  ) throws -> [WorktreeFileFailure.Item] {
    let manager = FileManager.default
    let repositoryBase = repository.resolvingSymlinksInPath()
    let worktreeBase = worktree.resolvingSymlinksInPath()
    var failures: [WorktreeFileFailure.Item] = []
    var skipped: [WorktreeFileFailure.Item] = []

    // On the spelling, before the disk, so `~/.aws.json` is refused rather
    // than skipped for not existing under the repository. See settings.md.
    var listed: [String] = []
    for path in Self.paths(in: list) {
      if !RepositoryContainment.holds(listedPath: path, under: repository) {
        let item = WorktreeFileFailure.Item(path: path, underlying: WorktreeFileEscape())
        if heldToRepository { failures.append(item) } else { skipped.append(item) }
        continue
      }
      listed.append(path)
    }

    for path in listed.flatMap({ Self.expand($0, in: repository) }) {
      guard !isStopped() else {
        throw WorktreeFilesStopped(failures: failures, skipped: skipped)
      }
      let source = repository.appendingPathComponent(path)
      let destination = worktree.appendingPathComponent(path)
      // A path the repository does not have is the quiet case and comes
      // first, so `.env` on a checkout without one is not an escape.
      guard manager.fileExists(atPath: source.path) else { continue }
      let landsInWorktree = Self.isInside(
        worktreeBase, destination.deletingLastPathComponent().splitAtDeepestExisting().existing)
      if heldToRepository {
        // Each end as on disk, the source itself included: `copyItem` carries
        // a symlink rather than following it. See Docs/design/hooks.md.
        guard landsInWorktree,
          Self.isInside(repositoryBase, source.deletingLastPathComponent()),
          Self.isInside(repositoryBase, source)
        else {
          failures.append(WorktreeFileFailure.Item(path: path, underlying: WorktreeFileEscape()))
          continue
        }
      } else if !landsInWorktree {
        // The destination is mirrored from the entry rather than asked for,
        // so a user's own entry pointing out places nothing, and is named.
        skipped.append(WorktreeFileFailure.Item(path: path, underlying: WorktreeFileEscape()))
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
          try Self.copy(source, to: destination, isStopped: isStopped)
        }
      } catch is WorktreeFilesStopped {
        throw WorktreeFilesStopped(failures: failures, skipped: skipped)
      } catch {
        failures.append(WorktreeFileFailure.Item(path: path, underlying: error))
      }
    }
    guard failures.isEmpty else {
      throw WorktreeFileFailure(
        placement: placement, items: failures, skippedEntries: skipped.map(\.path))
    }
    return skipped
  }

  /// A directory entry by entry, asking `isStopped` before each, so a large
  /// one ends at the next file on Cancel; `copyItem` alone takes it whole.
  static func copy(_ source: URL, to destination: URL, isStopped: () -> Bool) throws {
    let manager = FileManager.default
    var isDirectory: ObjCBool = false
    guard manager.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue,
      (try? source.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink != true
    else {
      try manager.copyItem(at: source, to: destination)
      return
    }
    // Modes go on last, deepest first: a 0555 folder made first takes no children.
    var made: [(directory: URL, source: URL)] = []
    defer { for (directory, source) in made.reversed() { copyMode(of: source, to: directory) } }
    try manager.createDirectory(at: destination, withIntermediateDirectories: false)
    made.append((destination, source))
    // Nil, the enumerator walks on past a folder it cannot read and the copy
    // reads as whole where `copyItem` would have thrown.
    var unread: (any Error)?
    let entries = manager.enumerator(
      at: source, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
      options: [.producesRelativePathURLs]
    ) { _, error in
      unread = error
      return false
    }
    do {
      while let entry = entries?.nextObject() as? URL {
        guard !isStopped() else { throw WorktreeFilesStopped() }
        let target = destination.appendingPathComponent(entry.relativePath)
        let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        if values.isDirectory == true, values.isSymbolicLink != true {
          try manager.createDirectory(at: target, withIntermediateDirectories: false)
          made.append((target, entry))
        } else {
          try manager.copyItem(at: entry, to: target)
        }
      }
      if let unread { throw unread }
    } catch {
      // Half a directory would read as placed, and nothing places over it.
      made = []
      try? manager.removeItem(at: destination)
      throw error
    }
  }

  private static func copyMode(of source: URL, to directory: URL) {
    let manager = FileManager.default
    if let mode = try? manager.attributesOfItem(atPath: source.path)[.posixPermissions] {
      try? manager.setAttributes([.posixPermissions: mode], ofItemAtPath: directory.path)
    }
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
  private static func isInside(_ base: URL, _ url: URL) -> Bool {
    url.resolvingSymlinksInPath().pathComponents(under: base) != nil
  }
}
