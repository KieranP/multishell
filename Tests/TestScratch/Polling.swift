import Foundation

/// Polls `condition` on the caller's actor until it holds or `seconds` pass;
/// the assertion after it says which.
public func waitUntil(
  _ condition: () -> Bool, seconds: Double = 8, isolation: isolated (any Actor)? = #isolation
) async throws {
  for _ in 0..<Int(seconds * 20) where !condition() {
    try await Task.sleep(for: .milliseconds(50))
  }
}

/// The lowest `/dev/fd` count over `window`. Other suites share the process, so a short
/// window can catch their burst as a leak; the lowest over a long one is their floor.
public func lowestDescriptorCount(
  over window: Duration, every pause: Duration = .milliseconds(100)
) async throws -> Int {
  var lowest = Int.max
  let deadline = ContinuousClock.now + window
  repeat {
    lowest = min(lowest, try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count)
    try await Task.sleep(for: pause)
  } while ContinuousClock.now < deadline
  return lowest
}
