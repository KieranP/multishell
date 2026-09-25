import Foundation
import MultishellCore

/// Puts a project's listed files into each new worktree, for what git does
/// not carry. One path per line, `*` and `?` allowed; see hooks.md.
public enum WorktreeFiles {
  /// The paths in a list, without blanks, comments or repeats. `place`
  /// judges what is in reach, against the disk.
  public static func paths(in list: String) -> [String] {
    var seen: Set<String> = []
    return LineList.entries(in: list).filter { seen.insert($0).inserted }
  }

  /// Links or copies each listed path, placing all it can before throwing, and
  /// returns a user's own entries that name somewhere else; see hooks.md.
  @discardableResult
  static func place(
    _ list: String, as placement: WorktreeFilePlacement, from repository: URL, to worktree: URL,
    heldToRepository: Bool = true, isStopped: @Sendable () -> Bool = { false }
  ) throws -> [String] {
    let manager = FileManager.default
    let repositoryBase = repository.resolvingSymlinksInPath()
    let worktreeBase = worktree.resolvingSymlinksInPath()
    let spelled = spellingCheck(Self.paths(in: list), under: repository)
    var failures = heldToRepository ? spelled.escapes : []
    var skipped = heldToRepository ? [] : spelled.escapes.map(\.path)

    for path in spelled.listed.flatMap({ WorktreeFilePattern.expand($0, in: repository) }) {
      guard !isStopped() else {
        throw WorktreeFileStopped(failures: failures, skipped: skipped)
      }
      let source = repository.appendingPathComponent(path)
      let destination = worktree.appendingPathComponent(path)
      // A path the repository does not have is the quiet case and comes
      // first, so `.env` on a checkout without one is not an escape.
      guard manager.fileExists(atPath: source.path) else { continue }
      let landsInWorktree = Self.isInside(
        destination.deletingLastPathComponent().splitAtDeepestExisting().existing,
        under: worktreeBase)
      if heldToRepository {
        // Each end as on disk, the source itself included: `copyItem` carries
        // a symlink rather than following it. See Docs/design/hooks.md.
        guard landsInWorktree,
          Self.isInside(source.deletingLastPathComponent(), under: repositoryBase),
          Self.isInside(source, under: repositoryBase)
        else {
          failures.append(
            WorktreeFileFailure.PathFailure(path: path, underlying: WorktreeFileEscape()))
          continue
        }
      } else if !landsInWorktree {
        // The destination is mirrored from the entry rather than asked for,
        // so a user's own entry pointing out places nothing, and is named.
        skipped.append(path)
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
      } catch is WorktreeFileStopped {
        throw WorktreeFileStopped(failures: failures, skipped: skipped)
      } catch {
        failures.append(WorktreeFileFailure.PathFailure(path: path, underlying: error))
      }
    }
    guard failures.isEmpty else {
      throw WorktreeFileFailure(placement: placement, failures: failures, skipped: skipped)
    }
    return skipped
  }

  /// On the spelling, before the disk, so `~/.aws.json` is refused rather
  /// than skipped for not existing under the repository. See settings.md.
  private static func spellingCheck(
    _ paths: [String], under repository: URL
  ) -> (listed: [String], escapes: [WorktreeFileFailure.PathFailure]) {
    var listed: [String] = []
    var escapes: [WorktreeFileFailure.PathFailure] = []
    for path in paths {
      if RepositoryContainment.holds(listedPath: path, under: repository) {
        listed.append(path)
      } else {
        escapes.append(
          WorktreeFileFailure.PathFailure(path: path, underlying: WorktreeFileEscape()))
      }
    }
    return (listed, escapes)
  }

  /// A directory entry by entry, asking `isStopped` before each, so a large
  /// one ends at the next file on Cancel; `copyItem` alone takes it whole.
  private static func copy(_ source: URL, to destination: URL, isStopped: () -> Bool) throws {
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
        guard !isStopped() else { throw WorktreeFileStopped() }
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

  /// Whether anything is at `url`, a symlink included, without asking where
  /// it leads: the question is what is in the way, not what resolves.
  private static func isPresent(_ url: URL) -> Bool {
    (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
  }

  /// Whether `url`, symlinks resolved, is `base` or something under it.
  private static func isInside(_ url: URL, under base: URL) -> Bool {
    url.resolvingSymlinksInPath().pathComponents(under: base) != nil
  }
}
