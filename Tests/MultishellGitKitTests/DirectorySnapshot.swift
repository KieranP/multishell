import Foundation
import Testing

/// Every file under a directory by inode, date and size, so two snapshots
/// differ wherever anything was written, replaced, added or removed.
struct DirectorySnapshot: Equatable {
  private struct Stamp: Equatable {
    let inode: Int
    let modified: Date
    let size: Int
  }

  private let stamps: [String: Stamp]

  init(of directory: URL) throws {
    let manager = FileManager.default
    var stamps: [String: Stamp] = [:]
    for path in try manager.subpathsOfDirectory(atPath: directory.path) {
      let attributes = try manager.attributesOfItem(
        atPath: directory.appendingPathComponent(path).path
      )
      stamps[path] = Stamp(
        inode: try #require(attributes[.systemFileNumber] as? Int),
        modified: try #require(attributes[.modificationDate] as? Date),
        size: try #require(attributes[.size] as? Int),
      )
    }
    self.stamps = stamps
  }
}
