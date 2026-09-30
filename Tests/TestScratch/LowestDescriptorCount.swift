import Foundation

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
