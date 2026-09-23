import Foundation

/// Whether a path reaches outside a repository. Nothing a committed
/// `.multishell.json` names may; see Docs/design/settings.md.
public enum RepositoryContainment {
  /// A directory, resolved the way the setting is, so a committed symlink
  /// cannot carry it out. `false` for the repository root itself.
  public static func holds(directory: URL, under repository: URL) -> Bool {
    guard let resolved = resolvedOnDisk(directory) else { return false }
    return resolved.pathComponents(under: repository.resolvingSymlinksInPath())?.isEmpty == false
  }

  /// `resolvingSymlinksInPath` returns a path that does not exist unchanged,
  /// links and all, so resolve what exists and append what is still to be
  /// made. `nil` where the deepest existing part is a link to nothing.
  private static func resolvedOnDisk(_ url: URL) -> URL? {
    var existing = url.standardizedFileURL
    var unmade: [String] = []
    while existing.pathComponents.count > 1,
      (try? FileManager.default.attributesOfItem(atPath: existing.path)) == nil
    {
      unmade.insert(existing.lastPathComponent, at: 0)
      existing = existing.deletingLastPathComponent()
    }
    guard FileManager.default.fileExists(atPath: existing.path) else { return nil }
    return unmade.reduce(existing.resolvingSymlinksInPath()) { $0.appendingPathComponent($1) }
  }

  /// Resolved against the root and required to land strictly under it, `..`
  /// resolved rather than counted; the disk is not asked. See settings.md.
  public static func holds(listedPath path: String, under repository: URL) -> Bool {
    let text = path.trimmingCharacters(in: .whitespaces)
    // A leading `$` only: nothing runs a shell on these, so `$HOME` further
    // in is a directory name the containment check settles like any other.
    guard !text.isEmpty, !text.hasPrefix("/"), !text.hasPrefix("~"), !text.hasPrefix("$")
    else { return false }
    let resolved = repository.appendingPathComponent(text).standardizedFileURL
    return resolved.pathComponents(under: repository.standardizedFileURL)?.isEmpty == false
  }

  /// The entries the root may name, as one text; `nil` where none is left. A
  /// list with nothing to drop comes back as written, since export rewrites it.
  public static func holding(listedPaths list: String?, under repository: URL) -> String? {
    guard let list else { return nil }
    let entries = LineList.entries(in: list)
    let kept = entries.filter { holds(listedPath: $0, under: repository) }
    guard kept.count != entries.count else { return list }
    return kept.isEmpty ? nil : kept.joined(separator: "\n")
  }
}
