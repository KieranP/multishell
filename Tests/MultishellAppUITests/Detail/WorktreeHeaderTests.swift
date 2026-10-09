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
    let worktree = harness.addPrimaryWorktree()
    harness.model.missingProjects = [harness.project.id]
    let theme = Theme.multishellDark
    let bitmap = try #require(
      OffscreenWindow.pixels(
        ofHosted: WorktreeHeader(model: harness.model, worktree: worktree, theme: theme),
        size: CGSize(width: 600, height: 40)))
    let sidebarColour = try #require(NSColor(theme.sidebarColor).usingColorSpace(bitmap.colorSpace))
    func isSidebarColour(_ x: Int, _ y: Int) -> Bool {
      guard let pixel = bitmap.colorAt(x: x, y: y) else { return false }
      return abs(pixel.redComponent - sidebarColour.redComponent) < 0.004
        && abs(pixel.greenComponent - sidebarColour.greenComponent) < 0.004
        && abs(pixel.blueComponent - sidebarColour.blueComponent) < 0.004
    }
    let filledInSidebarColour = (1..<bitmap.pixelsWide - 1).flatMap { x in
      (1..<bitmap.pixelsHigh - 1).filter { y in
        [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)].allSatisfy { isSidebarColour(x + $0, y + $1) }
      }
    }

    #expect(
      filledInSidebarColour.isEmpty,
      "\(filledInSidebarColour.count) pixels filled in the sidebar's colour")
  }
}
