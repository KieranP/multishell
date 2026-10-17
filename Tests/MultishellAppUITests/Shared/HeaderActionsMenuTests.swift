import SwiftUI
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct HeaderActionsMenuTests {
  @Test func theButtonIsDrawnInItsAreasSecondaryText() throws {
    let theme = try MagentaTheme.with([.header: [.textSecondary]])
    let menu = HeaderActionsMenu(help: "Actions", palette: theme.header) { Button("Item") {} }

    let bitmap = try #require(
      OffscreenWindow.pixels(ofHosted: menu.padding(4), size: CGSize(width: 40, height: 40))
    )

    #expect(MagentaTheme.pixelCount(in: bitmap) > 10)
  }
}
