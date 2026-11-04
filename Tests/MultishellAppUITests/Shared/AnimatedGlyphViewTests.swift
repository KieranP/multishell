import AppKit
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct AnimatedGlyphViewTests {
  private func glyphLayer(of view: AnimatedGlyphView) throws -> CAShapeLayer {
    try #require(view.layer?.sublayers?.first as? CAShapeLayer)
  }

  @Test(arguments: [GlyphMotion.orbit, .pulse, .turn])
  func aGlyphStrokedBeforeItHasAFrameHoldsNoPath(_ motion: GlyphMotion) throws {
    let view = AnimatedGlyphView(motion: motion)
    view.stroke(color: .systemBlue, lineWidth: 1.26)
    #expect(try glyphLayer(of: view).path == nil)
  }

  @Test func aGlyphGivenAnotherMotionStrokesThatMotionsPath() throws {
    let view = AnimatedGlyphView(motion: .turn)
    view.stroke(color: .systemBlue, lineWidth: 1.26)
    view.setFrameSize(NSSize(width: 7, height: 7))
    view.motion = .pulse
    let expected = GlyphMotion.pulse.path(in: view.bounds, lineWidth: 1.26)
    #expect(try glyphLayer(of: view).path == expected)
  }

  @Test(arguments: [GlyphMotion.orbit, .pulse, .turn])
  func aSizedGlyphStrokesAPathInsideItsFrame(_ motion: GlyphMotion) throws {
    let view = AnimatedGlyphView(motion: motion)
    view.stroke(color: .systemBlue, lineWidth: 1.26)
    view.setFrameSize(NSSize(width: 7, height: 7))
    let path = try #require(try glyphLayer(of: view).path)
    #expect(view.bounds.contains(path.boundingBoxOfPath))
  }
}
