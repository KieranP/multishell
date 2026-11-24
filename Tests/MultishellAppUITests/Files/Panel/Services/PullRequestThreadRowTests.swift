import AppKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore
@testable import MultishellServices

@Suite @MainActor
struct PullRequestThreadRowTests {
  @Test(arguments: [13.0, Appearance.uiFontSizes.upperBound])
  func anOutdatedThreadByALongLoginPaintsNothingPastThePanelsNarrowest(fontSize: Double) throws {
    let harness = ModelHarness()
    let worktree = harness.addPrimaryWorktree()
    harness.model.setUIFontSize(fontSize)
    let metrics = harness.model.metrics
    let thread = PullRequestThread(
      id: "t1",
      path: "app/jobs/data_push_job.rb",
      line: nil,
      originalLine: 28,
      isOutdated: true,
      diffHunk: "",
      comments: [
        PullRequestThreadComment(
          id: "c1",
          author: "github-code-quality",
          body: "## Potentially uninitialized local variable",
          bodyText: "Potentially uninitialized local variable",
          url: nil,
        )
      ],
    )
    let row = PullRequestThreadRow(
      model: harness.model,
      thread: thread,
      candidate: HandoffCandidate(.thread(id: "t1", newestCommentID: "c1")),
      worktreeID: worktree.id,
      theme: .multishellDark,
    )
    let width =
      FilesPanelWidth.minimum - 2 * UIMetrics.servicePageSideInset - metrics.serviceGlyphSize
      - UIMetrics.servicePageGlyphSpacing
    let margin = 40.0
    let box = NSView(frame: NSRect(x: 0, y: 0, width: width + 2 * margin, height: 120))
    let window = OffscreenWindow.holding(box, deferred: false)
    let host = NSHostingView(rootView: row.frame(width: width))
    host.frame = NSRect(x: margin, y: 0, width: width, height: 120)
    box.addSubview(host)
    box.layoutSubtreeIfNeeded()

    let bitmap = try #require(OffscreenWindow.pixels(of: box))
    let scale = Double(bitmap.pixelsWide) / box.bounds.width
    let paintedOutside = (0..<bitmap.pixelsHigh).filter { y in
      stride(from: 1.0, to: margin, by: 1).contains { offset in
        [margin - offset, margin + width + offset].contains { x in
          (bitmap.colorAt(x: Int(x * scale), y: y)?.alphaComponent ?? 0) > 0
        }
      }
    }
    #expect(paintedOutside.isEmpty)
    withExtendedLifetime(window) {}
  }
}
