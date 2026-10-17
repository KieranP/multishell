import SwiftUI
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct FilesPanelFilterFieldTests {
  @Test func thePromptIsDrawnInThePanelsFaintestText() throws {
    let harness = ModelHarness()
    let worktree = harness.addPrimaryWorktree()
    let theme = try MagentaTheme.with([.filesPanel: [.textTertiary]])
    let field = FilesPanelFilterField(model: harness.model, worktreeID: worktree.id, theme: theme)

    let bitmap = try #require(
      OffscreenWindow.pixels(ofHosted: field, size: CGSize(width: 240, height: 48))
    )

    #expect(MagentaTheme.pixelCount(in: bitmap, fromX: bitmap.pixelsWide / 4) > 10)
  }
}
