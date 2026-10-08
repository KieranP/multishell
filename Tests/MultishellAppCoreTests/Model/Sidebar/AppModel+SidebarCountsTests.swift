import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelSidebarCountsTests {
  @Test func theFootCountsWorktreesAndTerminalsInTheirPlurals() {
    let harness = Harness()
    #expect(harness.model.sidebarCountsText == "2 worktrees · 0 terminals")

    harness.model.select(harness.main)

    #expect(harness.model.sidebarCountsText == "2 worktrees · 1 terminal")
  }
}
