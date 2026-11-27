import Foundation

extension URL {
  /// The components below `base`: empty where this is `base`, `nil` where it
  /// is not under it. Whole components, so `/a/bc` is not under `/a/b`.
  public func pathComponents(under base: URL) -> [String]? {
    let root = base.standardizedFileURL.pathComponents
    let leaf = standardizedFileURL.pathComponents
    guard leaf.count >= root.count, leaf.prefix(root.count).elementsEqual(root) else { return nil }
    return Array(leaf.dropFirst(root.count))
  }

  /// The components below `base` once links in both are resolved as far as they exist;
  /// `nil` unless strictly under it, so a link cannot carry a path out.
  public func resolvedComponents(strictlyUnder base: URL) -> ArraySlice<String>? {
    guard let leaf = resolvedAsFarAsItExists()?.pathComponents,
      let root = base.resolvedAsFarAsItExists()?.pathComponents,
      // Not `pathComponents(under:)`: standardizing drops `/private` only from a path on disk.
      leaf.count > root.count, leaf.starts(with: root)
    else { return nil }
    return leaf.dropFirst(root.count)
  }
}
