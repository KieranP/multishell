import QuartzCore
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct GlyphMotionTests {
  @Test(arguments: [GlyphMotion.orbit, .pulse, .turn])
  func glyphsStartedAtDifferentMomentsMoveInStep(_ motion: GlyphMotion) {
    let early = motion.animation(at: 1000.25)
    let late = motion.animation(at: 1003.7)
    #expect(abs(early.beginTime.remainder(dividingBy: motion.cycle)) < 1e-9)
    #expect(abs(late.beginTime.remainder(dividingBy: motion.cycle)) < 1e-9)
  }
}
