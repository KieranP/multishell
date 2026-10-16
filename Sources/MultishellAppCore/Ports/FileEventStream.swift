import CoreServices
import Foundation

/// One running FSEvents stream over a set of directories, each batch handed
/// to a `FileEventBatchReceiver` on the stream's own queue.
final class FileEventStream: @unchecked Sendable {
  private let stream: FSEventStreamRef
  private var isInvalidated = false

  /// Nil where there is nothing to watch or FSEvents refuses the stream.
  init?(
    watched: WatchedDirectories,
    latency: TimeInterval,
    onChange: @escaping @Sendable ([URL]) -> Void,
  ) {
    guard !watched.realPaths.isEmpty else { return nil }
    let receiver = FileEventBatchReceiver(watched: watched, onChange: onChange)
    var context = FSEventStreamContext(
      version: 0,
      info: Unmanaged.passUnretained(receiver).toOpaque(),
      retain: { info in
        guard let info else { return nil }
        _ = Unmanaged<FileEventBatchReceiver>.fromOpaque(info).retain()
        return info
      },
      release: { info in
        guard let info else { return }
        Unmanaged<FileEventBatchReceiver>.fromOpaque(info).release()
      },
      copyDescription: nil,
    )
    let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
      guard let info else { return }
      let names = paths.assumingMemoryBound(to: UnsafePointer<CChar>.self)
      Unmanaged<FileEventBatchReceiver>.fromOpaque(info).takeUnretainedValue().receive(
        (0..<count).map { String(cString: names[$0]) },
        flags: Array(UnsafeBufferPointer(start: flags, count: count)),
      )
    }
    // At the top of `.git`, `FETCH_HEAD` and `HEAD` share a directory.
    let perFile = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
    guard
      let stream = FSEventStreamCreate(
        kCFAllocatorDefault,
        callback,
        &context,
        watched.realPaths as CFArray,
        FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
        latency,
        perFile,
      )
    else { return nil }
    self.stream = stream
    FSEventStreamSetDispatchQueue(stream, DispatchQueue(label: "multishell.fsevents"))
    guard FSEventStreamStart(stream) else {
      invalidate()
      return nil
    }
  }

  /// Stops the stream for good; safe to call again.
  func invalidate() {
    guard !isInvalidated else { return }
    isInvalidated = true
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)
  }

  deinit { invalidate() }
}
