import Foundation

/// Polls `condition` on the caller's actor until it holds or `seconds` pass;
/// the assertion after it says which.
public func waitUntil(
  _ condition: () -> Bool,
  seconds: Double = 8,
  isolation: isolated (any Actor)? = #isolation,
) async throws {
  for _ in 0..<Int(seconds * 20) where !condition() {
    try await Task.sleep(for: .milliseconds(50))
  }
}
