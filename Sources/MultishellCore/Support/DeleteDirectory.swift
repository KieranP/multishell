import Foundation

public func deleteDirectory(_ url: URL) async throws {
  try await runOnDispatch { try FileManager.default.removeItem(at: url) }
}
