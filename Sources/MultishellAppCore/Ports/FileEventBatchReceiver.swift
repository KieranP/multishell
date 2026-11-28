import CoreServices
import Foundation

/// What a `FileEventStream` hands each batch to, on the stream's own queue:
/// each path becomes the directory holding it, as `WatchedDirectories` reports it.
final class FileEventBatchReceiver: Sendable {
  /// A drop, or events coalesced into one at a folder whose whole subtree may have changed.
  private static let rescanFlags = FSEventStreamEventFlags(
    kFSEventStreamEventFlagUserDropped | kFSEventStreamEventFlagKernelDropped
      | kFSEventStreamEventFlagMustScanSubDirs
  )

  private let watched: WatchedDirectories
  private let onChange: @Sendable ([URL]) -> Void

  init(watched: WatchedDirectories, onChange: @escaping @Sendable ([URL]) -> Void) {
    self.watched = watched
    self.onChange = onChange
  }

  /// A batch dropped or coalesced names nothing usable, so every watched
  /// directory counts as changed.
  func receive(_ paths: [String], flags: [FSEventStreamEventFlags]) {
    if flags.contains(where: { $0 & Self.rescanFlags != 0 }) {
      onChange(watched.directories)
      return
    }
    let changed = Set(paths.compactMap(watched.reportedURL(forEventAt:)))
    if !changed.isEmpty { onChange(Array(changed)) }
  }
}
