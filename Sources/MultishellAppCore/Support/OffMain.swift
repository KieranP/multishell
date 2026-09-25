import Dispatch

/// For the polling paths' reads, the Trash and the watcher's opens, which a dead
/// mount blocks. On Dispatch, as a blocked `Task.detached` holds a pool thread.
func offMain<T: Sendable>(_ work: @Sendable @escaping () -> T) async -> T {
  await withCheckedContinuation { continuation in
    DispatchQueue.global(qos: .utility).async { continuation.resume(returning: work()) }
  }
}
