import Foundation
import MultishellCore

func deleteDirectory(_ url: URL) async throws {
  try await offMain { Result { try FileManager.default.removeItem(at: url) } }.get()
}
