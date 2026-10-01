import AppKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct WorktreeHeaderTests {
  @Test func aMissingProjectsBadgeIsRingedInTheHeadersColourNotTheSidebars() throws {
    let harness = ModelHarness()
    let worktree = Worktree(
      path: harness.project.path, projectID: harness.project.id, head: "abc1234",
      branch: "main", isPrimary: true)
    harness.store.replaceWorktrees([worktree], forProject: harness.project.id)
    harness.model.missingProjects = [harness.project.id]
    let theme = Theme.multishellDark
    let host = NSHostingView(
      rootView: WorktreeHeader(model: harness.model, worktree: worktree, theme: theme))
    host.frame = NSRect(x: 0, y: 0, width: 600, height: 40)
    let window = OffscreenWindow.holding(host, deferred: false)

    let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: rep)
    let sidebarColour = try #require(NSColor(theme.sidebarColor).usingColorSpace(rep.colorSpace))
    func isSidebarColour(_ x: Int, _ y: Int) -> Bool {
      guard let pixel = rep.colorAt(x: x, y: y) else { return false }
      return abs(pixel.redComponent - sidebarColour.redComponent) < 0.004
        && abs(pixel.greenComponent - sidebarColour.greenComponent) < 0.004
        && abs(pixel.blueComponent - sidebarColour.blueComponent) < 0.004
    }
    let filledInSidebarColour = (1..<rep.pixelsWide - 1).flatMap { x in
      (1..<rep.pixelsHigh - 1).filter { y in
        [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)].allSatisfy { isSidebarColour(x + $0, y + $1) }
      }
    }

    #expect(
      filledInSidebarColour.isEmpty,
      "\(filledInSidebarColour.count) pixels filled in the sidebar's colour")
    withExtendedLifetime(window) {}
  }
}
