import Foundation
import Testing

@testable import MultishellCore

struct FileTabTests {
  @Test func aTabSavedBeforeScrollsWereKeptReadsAsUnscrolled() throws {
    let tab = try decodeJSON(
      FileTab.self,
      #"{ "id": "\#(UUID())", "worktreeID": "/repo/main", "path": "README.md" }"#,
    )

    #expect(tab.scroll == nil)
  }
}
