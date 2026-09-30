import Foundation
import Synchronization

/// Collects one pipe to EOF without blocking a thread.
final class PipeBuffer: Sendable {
  private let state = Mutex<(buffer: Data, finished: Bool)>((Data(), false))
  private let handle: FileHandle
  private let group: DispatchGroup

  init(_ reading: FileHandle, group: DispatchGroup) {
    handle = reading
    self.group = group
    group.enter()
    handle.readabilityHandler = { [self] handle in
      let chunk = handle.availableData
      if chunk.isEmpty {
        finish()
      } else {
        append(chunk)
      }
    }
  }

  var data: Data {
    state.withLock { $0.buffer }
  }

  private func append(_ chunk: Data) {
    state.withLock {
      if !$0.finished { $0.buffer.append(chunk) }
    }
  }

  /// Stops reading and counts the pipe as drained. Only the first call does
  /// anything.
  func finish() {
    let first = state.withLock { state in
      defer { state.finished = true }
      return !state.finished
    }
    guard first else { return }
    handle.readabilityHandler = nil
    group.leave()
  }

  /// For a child that never started: stop waiting and release the pipe.
  func cancel() {
    finish()
    try? handle.close()
  }
}
