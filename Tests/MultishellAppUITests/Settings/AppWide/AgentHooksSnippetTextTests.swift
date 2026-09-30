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
    let host = NSHostingView(rootView: view.frame(width: 300, height: 60, alignment: .top))
    host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
    let window = OffscreenWindow.holding(host, deferred: false)

    let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: rep)
    let scale = Double(rep.pixelsWide) / host.bounds.width
    let firstLineLeft = try #require(firstLineLeftmostInk(rep, lineHeight: Int(8 * scale)))

    #expect(
      Double(firstLineLeft) / scale < 10,
      "the first line's ink starts \(Double(firstLineLeft) / scale)pt in")
    withExtendedLifetime(window) {}
  }
}

@MainActor
private func firstLineLeftmostInk(_ rep: NSBitmapImageRep, lineHeight: Int) -> Int? {
  func inked(_ x: Int, _ y: Int) -> Bool { (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.3 }
  let columns = 0..<rep.pixelsWide
  guard let top = (0..<rep.pixelsHigh).first(where: { y in columns.contains { inked($0, y) } })
  else { return nil }
  let band = top..<min(top + lineHeight, rep.pixelsHigh)
  return columns.first { x in band.contains { inked(x, $0) } }
}
