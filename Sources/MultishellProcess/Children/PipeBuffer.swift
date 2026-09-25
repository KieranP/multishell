import Foundation
import Synchronization
import System

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

  /// Both ends of a new pipe, or `PipeUnavailable`. Not `Pipe()`, which cannot
  /// fail and so returns two handles on descriptor 0 at the limit.
  static func makePipe() throws -> (reading: FileHandle, writing: FileDescriptor) {
    var descriptors: [Int32] = [-1, -1]
    guard pipe(&descriptors) == 0 else { throw PipeUnavailable(code: errno) }
    // macOS has no pipe2, so a fork between the two calls still inherits them.
    for descriptor in descriptors { _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC) }
    return (
      FileHandle(fileDescriptor: descriptors[0], closeOnDealloc: true),
      FileDescriptor(rawValue: descriptors[1])
    )
  }
}
