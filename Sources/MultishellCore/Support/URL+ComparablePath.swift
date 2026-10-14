import Foundation

extension URL {
  /// Links followed and `..` resolved, so two spellings of one place compare
  /// equal.
  public var comparablePath: String {
    resolvingSymlinksInPath().standardizedFileURL.path
  }
}
