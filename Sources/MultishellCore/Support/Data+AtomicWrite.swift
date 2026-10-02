import Foundation

extension Data {
  func writeAtomicallyCreatingDirectory(to file: URL) throws {
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try write(to: file, options: .atomic)
  }
}
