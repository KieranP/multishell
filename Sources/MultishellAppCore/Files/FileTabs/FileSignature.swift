import Foundation

/// What says a file changed without reading it: its size, date and inode, by
/// `lstat`, so an atomic save that swaps the inode counts.
struct FileSignature: Equatable, Sendable {
  private let size: Int
  private let modified: Date
  private let inode: Int

  /// `nil` where nothing is there.
  static func of(_ url: URL) -> Self? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
      let size = attributes[.size] as? Int,
      let modified = attributes[.modificationDate] as? Date,
      let inode = attributes[.systemFileNumber] as? Int
    else { return nil }
    return Self(size: size, modified: modified, inode: inode)
  }
}
