import MultishellCore
import Testing

@testable import MultishellGitKit

@Suite
struct StatusEntryTests {
  @Test func anIntentToAddFileIsAdded() {
    let entry = StatusEntry(indexState: " ", workTreeState: "A", path: "new.txt")

    #expect(entry.changeKind(counting: .stagedAndUnstaged) == .added)
  }
}
