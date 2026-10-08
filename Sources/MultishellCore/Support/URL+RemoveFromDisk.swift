import Foundation

extension URL {
  /// Deletes what is here outright, a link inside removed rather than followed,
  /// on a Dispatch thread so a slow disk holds no pool thread.
  public func removeFromDisk() async throws {
    let url = self
    try await runOnDispatch { try FileManager.default.removeItem(at: url) }
  }
}
