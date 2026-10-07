import Foundation

extension URL {
  /// Whether anything is at this path, a symlink included, without asking
  /// where it leads: what is in the way, not what resolves.
  public var hasEntryOnDisk: Bool {
    (try? FileManager.default.attributesOfItem(atPath: path)) != nil
  }
}
