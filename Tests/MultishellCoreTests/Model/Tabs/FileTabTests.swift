import Foundation
import Testing

@testable import MultishellCore

struct FileTabTests {
  @Test func aPathClimbingOutWithACombiningMarkAfterItsSlashIsNotContained() {
    #expect(!FileTab.isContained("../\u{0301}x"))
    #expect(!FileTab.isContained("a/../\u{0301}x"))
    #expect(FileTab.isContained("a/\u{0301}x"))
  }

  @Test func aTabSavedBeforeScrollsWereKeptReadsAsUnscrolled() throws {
    let tab = try decodeJSON(
      FileTab.self,
      #"{ "id": "\#(UUID())", "worktreeID": "/repo/main", "path": "README.md" }"#,
    )

    #expect(tab.scroll == nil)
  }
}
