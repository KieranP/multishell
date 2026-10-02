import AppKit
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

/// A view that cannot shrink draws past its frame rather than reporting it,
/// so this reads the pixels either side of the pane.
@Suite @MainActor
struct DetailViewTests {
  @Test func theHeaderDrawsNothingOutsideTheNarrowestDetail() throws {
    let harness = ModelHarness()
    let worktree = harness.addPrimaryWorktree(branch: "feature/a-branch")
    harness.store.selectWorktree(worktree.id)
    try #require(harness.model.workspace.selectedWorktree != nil)

    let width = SidebarWidth.minimumDetail
    let margin = 100.0
    let box = NSView(frame: NSRect(x: 0, y: 0, width: width + 2 * margin, height: 60))
    let window = OffscreenWindow.holding(box, deferred: false)
    let host = NSHostingView(rootView: DetailView(model: harness.model))
    host.frame = NSRect(x: margin, y: 0, width: width, height: 60)
    box.addSubview(host)
    box.layoutSubtreeIfNeeded()

    let bitmap = try #require(OffscreenWindow.pixels(of: box))
    let scale = Double(bitmap.pixelsWide) / box.bounds.width
    let row = bitmap.pixelsHigh / 4
    for x in [margin - 10, margin + width + 10] {
      let alpha = bitmap.colorAt(x: Int(x * scale), y: row)?.alphaComponent ?? 0
      #expect(alpha == 0, "painted at \(x)pt, outside the pane's \(margin)-\(margin + width)")
    }
    withExtendedLifetime(window) {}
  }
}
