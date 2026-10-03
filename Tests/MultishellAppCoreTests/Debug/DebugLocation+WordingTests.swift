import Testing

@testable import MultishellAppCore

@Suite
struct DebugLocationWordingTests {
  @Test func aLocationIsNamedProjectThenWorktreeOrByItsDirectoryAlone() {
    #expect(DebugLocation(projectName: "acme", worktreeName: "main").title == "acme / main")
    #expect(DebugLocation(projectName: nil, worktreeName: "scratch").title == "scratch")
  }
}
