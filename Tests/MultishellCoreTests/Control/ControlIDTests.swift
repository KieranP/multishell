import Testing

@testable import MultishellCore

@Suite
struct ControlIDTests {
  @Test func anIDIsShortTheSameEachTimeAndTellsAProjectFromAWorktree() {
    let project = ControlID.project("/Users/k/Work/app")

    #expect(project == ControlID.project("/Users/k/Work/app"))
    #expect(project != ControlID.project("/Users/k/Work/app2"))
    #expect(project.count == 10)
    #expect(ControlID.isProject(project))
    #expect(!ControlID.isWorktree(project))
    #expect(ControlID.isWorktree(ControlID.worktree("/Users/k/Work/app")))
  }

  @Test func onlyAnIDsOwnSpellingReadsAsOne() {
    for text in ["p-3f9a2c1", "p-3F9A2C1D", "p-3f9a2c1dd", "q-3f9a2c1d", "/repo", "app"] {
      #expect(!ControlID.isProject(text), "\(text)")
    }
  }
}
