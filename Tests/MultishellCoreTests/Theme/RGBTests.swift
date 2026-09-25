import Testing

@testable import MultishellCore

@Suite
struct RGBTests {
  @Test func chromeLiftsTowardsTheOppositeOfTheBackground() {
    let dark = Theme.multishellDark
    let light = Theme.multishellLight
    let lifted = dark.backgroundRGB.blended(with: .white, amount: 0.09)
    #expect(lifted.red > dark.backgroundRGB.red)
    let sunk = light.backgroundRGB.blended(with: .black, amount: 0.09)
    #expect(sunk.red < light.backgroundRGB.red)
  }

  @Test func blendingClampsAndRounds() {
    let rgb = RGB(red: 10, green: 20, blue: 30)
    #expect(rgb.blended(with: .white, amount: 2) == .white)
    #expect(rgb.blended(with: .white, amount: -1) == rgb)
    #expect(
      rgb.blended(with: RGB(red: 20, green: 20, blue: 20), amount: 0.5)
        == RGB(red: 15, green: 20, blue: 25))
  }
}
