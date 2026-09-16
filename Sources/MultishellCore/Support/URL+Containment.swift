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
}
