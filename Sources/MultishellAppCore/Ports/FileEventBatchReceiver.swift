import CoreServices
import Foundation

/// What a `FileEventStream` hands each batch to, on the stream's own queue:
/// each path becomes the directory holding it, as `WatchedDirectories` reports it.
final class FileEventBatchReceiver: Sendable {
  private static let droppedFlags = FSEventStreamEventFlags(
    kFSEventStreamEventFlagUserDropped | kFSEventStreamEventFlagKernelDropped
  )

  private let watched: WatchedDirectories
  private let onChange: @Sendable ([URL]) -> Void

  init(watched: WatchedDirectories, onChange: @escaping @Sendable ([URL]) -> Void) {
    self.watched = watched
    self.onChange = onChange
  }

  /// A batch the kernel or fseventsd dropped names nothing usable, so every
  /// watched directory counts as changed.
  func receive(_ paths: [String], flags: [FSEventStreamEventFlags]) {
    if flags.contains(where: { $0 & Self.droppedFlags != 0 }) {
      onChange(watched.directories)
      return
    }
    let changed = Set(paths.compactMap(watched.reportedURL(forEventAt:)))
    if !changed.isEmpty { onChange(Array(changed)) }
  }
}
