import AppKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct ReviewSendFooterTests {
  private static func footer(
    in harness: ModelHarness,
    fontSize: Double = 13,
  ) throws -> ReviewSendFooter {
    let worktree = harness.addPrimaryWorktree()
    harness.model.select(worktree)
    harness.model.setUIFontSize(fontSize)
    harness.store.openTab(in: worktree.id, title: "claude", agentID: AgentCatalogue.claudeID)
    harness.model.liveSessionIDs = Set(harness.model.workspace.sessions(in: worktree.id).map(\.id))
    let offersTheAgent =
      if case .ready = harness.model.reviewFooter(of: worktree) { true } else { false }
    try #require(offersTheAgent)
    return ReviewSendFooter(model: harness.model, worktree: worktree, theme: .multishellDark)
  }

  private static func height(ofFooterAtWidth width: CGFloat) throws -> CGFloat {
    let harness = ModelHarness()
    return OffscreenHost.read(
      try footer(in: harness),
      atWidth: width,
      windowSize: CGSize(width: width, height: 400),
    ) { $0.fittingSize.height }
  }

  @Test func atThePanelsNarrowestTheFooterStaysOneLineHigh() throws {
    let wide = try Self.height(ofFooterAtWidth: 480)
    let narrowest = try Self.height(ofFooterAtWidth: FilesPanelWidth.minimum)

    #expect(narrowest == wide)
  }

  @Test func atThePanelsNarrowestInTheLargestFontTheFooterPaintsNothingPastItsEdges() throws {
    let harness = ModelHarness()
    let footer = try Self.footer(in: harness, fontSize: Appearance.uiFontSizes.upperBound)
    let width = FilesPanelWidth.minimum
    let margin = 20.0
    let box = NSView(frame: NSRect(x: 0, y: 0, width: width + 2 * margin, height: 60))
    let window = OffscreenWindow.holding(box, deferred: false)
    let host = NSHostingView(rootView: footer.frame(width: width))
    host.frame = NSRect(x: margin, y: 0, width: width, height: 60)
    box.addSubview(host)
    box.layoutSubtreeIfNeeded()

    let bitmap = try #require(OffscreenWindow.pixels(of: box))
    let scale = Double(bitmap.pixelsWide) / box.bounds.width
    let paintedOutside = (0..<bitmap.pixelsHigh).filter { y in
      [margin - 2, margin + width + 2].contains { x in
        (bitmap.colorAt(x: Int(x * scale), y: y)?.alphaComponent ?? 0) > 0
      }
    }
    #expect(paintedOutside.isEmpty)
    withExtendedLifetime(window) {}
  }
}
