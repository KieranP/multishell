import Foundation

extension URL {
  /// The deepest of this path and its ancestors that is on disk, and the
  /// names below it that are not. A link counts as there even where it dangles.
  public func splitAtDeepestExisting() -> (existing: URL, unmade: [String]) {
    var existing = standardizedFileURL
    var unmade: [String] = []
    while existing.pathComponents.count > 1,
      (try? FileManager.default.attributesOfItem(atPath: existing.path)) == nil
    {
      unmade.insert(existing.lastPathComponent, at: 0)
      existing = existing.deletingLastPathComponent()
    }
    return (existing, unmade)
  }

  /// Links resolved as far as the path exists, the rest appended; `nil` below a
  /// link to nothing unless it is kept by name. See Docs/design/settings.md.
  public func resolvedAsFarAsItExists(keepingDanglingLinks: Bool = false) -> URL? {
    var (existing, unmade) = splitAtDeepestExisting()
    while true {
      // `realpath` rather than Foundation, which drops the `/private` that git
      // keeps on `/var` and `/tmp`.
      if let resolved = realpath(existing.path, nil) {
        defer { free(resolved) }
        return unmade.reduce(URL(fileURLWithPath: String(cString: resolved))) {
          $0.appendingPathComponent($1)
        }
      }
      guard keepingDanglingLinks, existing.pathComponents.count > 1 else { return nil }
      unmade.insert(existing.lastPathComponent, at: 0)
      existing = existing.deletingLastPathComponent()
    }
  }
}
