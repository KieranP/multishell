import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppUI

/// A view that cannot shrink draws past its frame rather than reporting it,
/// so this reads the pixels either side of the pane.
@Suite @MainActor
struct DetailViewTests {
  @Test func theHeaderDrawsNothingOutsideTheNarrowestDetail() throws {
    let harness = ModelHarness()
    let worktree = Worktree(
      path: harness.project.path, projectID: harness.project.id,
      head: "abc1234", branch: "feature/a-branch", isPrimary: true)
    harness.store.replaceWorktrees([worktree], forProject: harness.project.id)
    harness.store.selectWorktree(worktree.id)
    try #require(harness.model.workspace.selectedWorktree != nil)

    let width = RootView.minimumDetailWidth
    let margin = 100.0
    let box = NSView(frame: NSRect(x: 0, y: 0, width: width + 2 * margin, height: 60))
    let window = NSWindow(
      contentRect: box.frame, styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = box
    let host = NSHostingView(rootView: DetailView(model: harness.model))
    host.frame = NSRect(x: margin, y: 0, width: width, height: 60)
    box.addSubview(host)
    box.layoutSubtreeIfNeeded()

    let rep = try #require(box.bitmapImageRepForCachingDisplay(in: box.bounds))
    box.cacheDisplay(in: box.bounds, to: rep)
    let scale = Double(rep.pixelsWide) / box.bounds.width
    let row = rep.pixelsHigh / 4
    for x in [margin - 10, margin + width + 10] {
      let alpha = rep.colorAt(x: Int(x * scale), y: row)?.alphaComponent ?? 0
      #expect(alpha == 0, "painted at \(x)pt, outside the pane's \(margin)-\(margin + width)")
    }
  }
}
