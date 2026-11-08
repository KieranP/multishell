import Foundation

extension Data {
  /// Over a link at the end of `file`, not through it: a caller writing the
  /// user's own file passes `file.linkTarget`, so a dotfiles repo keeps it.
  func writeAtomicallyCreatingDirectory(to file: URL) throws {
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(),
      withIntermediateDirectories: true,
    )
    try write(to: file, options: .atomic)
  }
}
