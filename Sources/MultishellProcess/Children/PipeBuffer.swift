import Foundation
import Synchronization

/// Collects one pipe to EOF without blocking a thread.
final class PipeBuffer: Sendable {
  private let state = Mutex<(buffer: Data, finished: Bool)>((Data(), false))
  private let handle: FileHandle
  private let group: DispatchGroup

  var collected: Data {
    state.withLock { $0.buffer }
  }

  init(_ reading: FileHandle, group: DispatchGroup) {
    handle = reading
    self.group = group
    group.enter()
    // Weak, as Foundation drops a cleared handler later on its own queue. The
    // run holds the buffer until it has read it.
    handle.readabilityHandler = { [weak self] handle in
      let chunk = handle.availableData
      if chunk.isEmpty {
        self?.finish()
      } else {
        self?.append(chunk)
      }
    }
  }

  private func append(_ chunk: Data) {
    state.withLock { state in
      if !state.finished { state.buffer.append(chunk) }
    }
  }

  /// Stops reading and counts the pipe as drained. Only the first call does
  /// anything.
  func finish() {
    let wasUnfinished = state.withLock { state in
      defer { state.finished = true }
      return !state.finished
    }
    guard wasUnfinished else { return }
    handle.readabilityHandler = nil
    group.leave()
  }

  /// For a child that never started: stop waiting and release the pipe.
  func cancel() {
    finish()
    try? handle.close()
  }
}
