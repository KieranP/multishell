import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AttentionDotTests {
  /// The dot means "something happened here since you looked", and the tab an
  /// exit reveals is being looked at, as if clicked.
  @Test func aTabRevealedByAnExitLosesItsDot() {
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let second = h.model.workspace.activeTab(in: h.main.id)!
    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: first.focusedSessionID)
    #expect(h.model.state(of: first) == .done)

    h.engine.delegate?.terminalHost(h.engine, didExit: second.focusedSessionID)

    #expect(h.model.workspace.activeTab(in: h.main.id)?.id == first.id)
    #expect(h.model.state(of: first) == nil)
    #expect(h.model.state(ofWorktree: h.main.id) == nil)
  }
}
