import Foundation

extension URL {
  /// Each directory from here up to `top` that holds nothing; one holding
  /// anything stops the walk, `removeItem` taking a directory whole.
  func removeEmptyDirectories(through top: URL) {
    let manager = FileManager.default
    var directory = standardizedFileURL
    let topDepth = top.standardizedFileURL.pathComponents.count
    while directory.pathComponents.count >= topDepth {
      // `rmdir` refuses a directory with anything in it, a create beside this
      // one having perhaps made its checkout there since.
      if manager.fileExists(atPath: directory.path), rmdir(directory.path) != 0 { return }
      directory = directory.deletingLastPathComponent()
    }
  }
}
