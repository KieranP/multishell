import Testing

@testable import MultishellAppCore

@Suite
struct NoSelectionTextTests {
  @Test func withNoProjectTheEmptyDetailSaysHowToStart() {
    #expect(NoSelectionText.title(hasProjects: false) == "Add a project to get started")
    #expect(NoSelectionText.caption(hasProjects: false).hasPrefix("Point Multishell at"))
  }

  @Test func withAProjectTheEmptyDetailPointsAtTheSidebar() {
    #expect(NoSelectionText.title(hasProjects: true) == "Select a worktree")
    #expect(NoSelectionText.caption(hasProjects: true).hasPrefix("Pick one in the sidebar"))
  }
}
