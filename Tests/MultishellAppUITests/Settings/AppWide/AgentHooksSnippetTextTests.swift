import AppKit
import SwiftUI
import Testing

@testable import MultishellAppUI

/// A grouped form's row sets its content's text alignment to trailing, and a
/// popover opened from the row inherits it.
@Suite @MainActor
struct AgentHooksSnippetTextTests {
  @Test func aShortFirstLineStartsAtTheLeftEdgeUnderAFormRowsAlignment() throws {
    let snippet = "{\n  \"hooks\": {}\n}\n"
    let view = AgentHooksSnippetText(snippet: snippet)
      .environment(\.multilineTextAlignment, .trailing)
    let width = 300.0
    let bitmap = try #require(
      OffscreenWindow.pixels(
        ofHosted: view.frame(width: width, height: 60, alignment: .top),
        size: CGSize(width: width, height: 60)))
    let scale = Double(bitmap.pixelsWide) / width
    let firstLineLeft = try #require(
      InkedPixels(bitmap).firstLineLeftmostColumn(lineHeight: Int(8 * scale)))

    #expect(
      Double(firstLineLeft) / scale < 10,
      "the first line's ink starts \(Double(firstLineLeft) / scale)pt in")
  }
}
