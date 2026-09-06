import MultishellCore
import Testing

@testable import Multishell

@Suite
struct UIMetricsTests {
  @Test func everySizeGrowsWithTheBase() {
    let small = UIMetrics(fontSize: 11)
    let large = UIMetrics(fontSize: 16)
    for keyPath in [
      \UIMetrics.body, \.secondary, \.caption, \.badge, \.mono, \.icon, \.rowHeight, \.tabHeight,
      \.indent,
    ] {
      #expect(small[keyPath: keyPath] < large[keyPath: keyPath])
    }
  }

  @Test func rowsAreTallEnoughForTheirText() {
    for size in stride(from: 10.0, through: 18.0, by: 1) {
      let metrics = UIMetrics(fontSize: size)
      #expect(metrics.rowHeight >= metrics.body * 1.8, "size \(size)")
      #expect(metrics.badge >= 7, "badge text must stay legible at \(size)")
    }
  }
}

@Suite
struct ThemeColourTests {
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
