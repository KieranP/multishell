import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct WorktreeKindTextTests {
  @Test func theKindNamesBareDetachedMainAndLinked() {
    let main = Worktree(
      path: URL(fileURLWithPath: "/r"), projectID: "/r", head: "abc", branch: "main",
      isPrimary: true)
    let feature = Worktree(
      path: URL(fileURLWithPath: "/trees/feat"), projectID: "/r", head: "abc", branch: "feat")
    let bare = Worktree(
      path: URL(fileURLWithPath: "/r.git"), projectID: "/r.git", head: "", isPrimary: true,
      isBare: true)
    let detached = Worktree(path: URL(fileURLWithPath: "/t/x"), projectID: "/r", head: "1a2e5c9ff")
    #expect(main.kindText() == "Main worktree")
    #expect(feature.kindText() == "Linked worktree")
    #expect(bare.kindText() == "Bare repository")
    #expect(detached.kindText() == "Detached at 1a2e5c9")
  }
}
