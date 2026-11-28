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

  /// Stops reading and counts the pipe as drained. Only the first call to
  /// this or `finishLeavingItOpen` does anything.
  func finish() {
    guard markFinished() else { return }
    handle.readabilityHandler = nil
    group.leave()
  }

  /// Counts the pipe as drained while a descendant still holds its write end,
  /// reading on and dropping what comes until EOF.
  func finishLeavingItOpen() {
    guard markFinished() else { return }
    // The handler holds the read end open: closing it killed a hook's
    // backgrounded server with SIGPIPE at its next line.
    let handle = handle
    handle.readabilityHandler = { _ in
      if handle.availableData.isEmpty { handle.readabilityHandler = nil }
    }
    group.leave()
  }

  private func markFinished() -> Bool {
    state.withLock { state in
      defer { state.finished = true }
      return !state.finished
    }
  }

  /// For a child that never started: stop waiting and release the pipe.
  func cancel() {
    finish()
    try? handle.close()
  }
}
