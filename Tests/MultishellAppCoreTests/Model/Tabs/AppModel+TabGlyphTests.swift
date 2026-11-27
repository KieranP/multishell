import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelTabGlyphTests {
  @Test func aTabShowsTheSplitMarkOverItsActionsAndTheActionsOverAShells() throws {
    let harness = Harness()
    let serve = ProjectAction(name: "Start Server", command: "npm run dev")
    harness.model.setSettings(ProjectSettings(actions: [serve]), for: harness.project)
    let shell = harness.openBackgroundTab()
    harness.model.runAction(named: serve.name, in: harness.main)
    let session = try #require(harness.model.actionSession(named: serve.name, in: harness.main.id))
    let action = try #require(harness.model.workspace.tab(owning: session.id))

    #expect(harness.model.glyph(of: shell) == .terminal)
    #expect(harness.model.glyph(of: action) == .action)

    harness.model.splitActivePane(.horizontal)
    let split = try #require(harness.model.workspace.tab(owning: session.id))
    #expect(harness.model.glyph(of: split) == .split)
  }
}
