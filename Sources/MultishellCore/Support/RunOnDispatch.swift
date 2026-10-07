import Dispatch

/// For blocking file work, which a dead mount can stall. On Dispatch, as a
/// blocked `Task.detached` holds a pool thread.
public func runOnDispatch<T: Sendable>(_ work: @Sendable @escaping () -> T) async -> T {
  await withCheckedContinuation { continuation in
    DispatchQueue.global(qos: .utility).async { continuation.resume(returning: work()) }
  }
}

func runOnDispatch<T: Sendable>(
  _ work: @Sendable @escaping () throws -> T
) async throws -> T {
  try await runOnDispatch { Result { try work() } }.get()
}
