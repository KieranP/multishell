import Foundation
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct GhosttySurfaceViewTests {
  @Test func aSurfaceKeepsTheRuntimeItWasMadeInAliveUntilFreed() throws {
    var runtime: GhosttyRuntime? = GhosttyRuntime()
    weak var heldRuntime = runtime
    let view = GhosttySurfaceView(runtime: try #require(runtime), launch: .sleeping)
    try #require(view.surface != nil)

    runtime = nil

    #expect(heldRuntime != nil)
    view.freeSurface()
  }
}
