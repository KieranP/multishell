import SwiftUI
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

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
}
