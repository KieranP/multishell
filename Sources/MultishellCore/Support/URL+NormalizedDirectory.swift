import Foundation

extension URL {
  /// A directory URL whether or not it exists now: `URL(fileURLWithPath:)`
  /// asks the filesystem, and a missing one resolves as a file.
  var normalizedDirectory: URL {
    URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
  }
}
