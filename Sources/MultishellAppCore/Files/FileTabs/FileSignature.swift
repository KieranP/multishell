import Foundation

/// What says a file changed without reading it: its size, date and inode, by
/// `lstat`, so an atomic save that swaps the inode counts.
struct FileSignature: Equatable, Sendable {
  let size: Int
  /// A folder listed as a change, a submodule or nested repository.
  let isFolder: Bool
  private let modified: Date
  private let inode: Int

  /// `nil` where nothing is there.
  static func of(_ url: URL) -> Self? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
      let size = attributes[.size] as? Int,
      let modified = attributes[.modificationDate] as? Date,
      let inode = attributes[.systemFileNumber] as? Int
    else { return nil }
    return Self(
      size: size,
      isFolder: attributes[.type] as? FileAttributeType == .typeDirectory,
      modified: modified,
      inode: inode,
    )
  }
}
