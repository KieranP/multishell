import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// Written to a repository and read back, so its digest is the sha256 of real bytes, which is
/// what a hook decision is held against.
func writtenAndReadBack(_ settings: SharedProjectSettings) throws -> SharedProjectSettings {
  let root = try Scratch.directory("shared")
  defer { try? FileManager.default.removeItem(at: root) }
  try settings.write(to: root)
  return try #require(try SharedProjectSettings.load(from: root))
}
