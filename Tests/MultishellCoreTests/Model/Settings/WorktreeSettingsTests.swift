import Foundation
import Testing

@testable import MultishellCore

@Suite
struct WorktreeSettingsTests {
  @Test func anEmptyObjectDecodesAsTheDefaultWorktreeSettings() throws {
    let settings = try decodeJSON(WorktreeSettings.self, "{}")
    #expect(settings == WorktreeSettings())
  }
}
