import Foundation

extension FileManager {
  /// A file that can be run. `isExecutableFile` alone passes a directory, as searchable.
  public func isRunnableFile(atPath path: String) -> Bool {
    var isDirectory: ObjCBool = false
    return fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue
      && isExecutableFile(atPath: path)
  }
}
