import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct AgentBoardHeaderTests {
  @Test func showingEveryTerminalTurnsTheToggleTheHeadersAccent() throws {
    let harness = ModelHarness()
    harness.model.showsAllTerminalsBinding.wrappedValue = true
    let theme = try MagentaTheme.with([.header: [.accent]])
    let header = AgentBoardHeader(
      model: harness.model,
      board: harness.model.agentBoard,
      theme: theme,
      metrics: harness.model.metrics,
    )

    let bitmap = try #require(
      OffscreenWindow.pixels(ofHosted: header, size: CGSize(width: 520, height: 44))
    )

    #expect(MagentaTheme.pixelCount(in: bitmap) > 10)
  }
}
