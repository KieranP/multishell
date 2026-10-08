import Foundation
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct GhosttySurfaceViewMemoryTests {
  @Test func aLiveSurfaceReportsTheMemoryItsScreenHolds() throws {
    let view = GhosttySurfaceView(runtime: GhosttyRuntime(), launch: .sleeping)
    defer { view.freeSurface() }
    try #require(view.surface != nil)

    let memory = try #require(view.terminalMemory)
    #expect(memory > 0)
  }

  @Test func aFreedSurfaceReportsNoMemoryRatherThanReadingFreedState() throws {
    let view = GhosttySurfaceView(runtime: GhosttyRuntime(), launch: .sleeping)
    try #require(view.surface != nil)

    view.freeSurface()

    #expect(view.terminalMemory == nil)
  }
}
