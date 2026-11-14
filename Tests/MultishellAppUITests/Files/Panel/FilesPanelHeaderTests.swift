import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore
@testable import MultishellServices

@Suite @MainActor
struct FilesPanelHeaderTests {
  @Test func theChosenListsGlyphReadsInTheHeadersText() throws {
    let harness = ModelHarness()
    _ = harness.addPrimaryWorktree()
    let theme = try MagentaTheme.with([.header: [.text]])
    let header = FilesPanelHeader(model: harness.model, theme: theme)

    let bitmap = try #require(
      OffscreenWindow.pixels(ofHosted: header, size: CGSize(width: 320, height: 40))
    )

    #expect(MagentaTheme.pixelCount(in: bitmap) > 10)
  }

  @Test func withThePullRequestAndCIPagesTheHeaderFitsThePanelsNarrowest() throws {
    let harness = ModelHarness()
    _ = harness.addPrimaryWorktree()
    harness.model.remoteState.connections = ServiceConnections(
      standIn: try ServiceStandIn(json: "{}")
    )
    try #require(harness.model.showsPullRequestPanelPage && harness.model.showsCIPanelPage)
    let header = FilesPanelHeader(model: harness.model, theme: .multishellDark)

    let width = NSHostingView(rootView: header).fittingSize.width

    #expect(width <= FilesPanelWidth.minimum)
  }
}
