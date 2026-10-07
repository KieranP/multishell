import Foundation
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct GhosttySurfaceViewTests {
  @Test func aSurfaceViewKeepsTheRuntimeItWasMadeInAlive() throws {
    var runtime: GhosttyRuntime? = GhosttyRuntime()
    weak let heldRuntime = runtime
    let view = GhosttySurfaceView(runtime: try #require(runtime), launch: .sleeping)
    try #require(view.surface != nil)

    runtime = nil

    #expect(heldRuntime != nil)
    view.freeSurface()
  }
}
