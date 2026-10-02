import Foundation

extension Data {
  /// Written whole to `file`, its directory made first if it is not there.
  func writeAtomically(to file: URL) throws {
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try write(to: file, options: .atomic)
  }
}
