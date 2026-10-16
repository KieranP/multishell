import Foundation

/// A path's components, standardized once, and what the path belongs to, for
/// matching thousands of changed paths against it.
struct StandardizedPath<ID> {
  let id: ID
  private let components: [String]

  init(id: ID, url: URL) {
    self.id = id
    components = url.standardizedFileURL.pathComponents
  }

  /// What lies below this path on the way to `other`; nil where it is not under.
  func subpath(to other: [String]) -> ArraySlice<String>? {
    other.starts(with: components) ? other.dropFirst(components.count) : nil
  }
}
