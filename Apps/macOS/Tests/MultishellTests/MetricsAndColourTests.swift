import MultishellCore
import Testing

@testable import Multishell

@Suite
struct UIMetricsTests {
  @Test func everySizeGrowsWithTheBase() {
    let small = UIMetrics(fontSize: 11)
    let large = UIMetrics(fontSize: 16)
    for keyPath in [
      \UIMetrics.body, \.secondary, \.caption, \.badge, \.mono, \.icon, \.rowHeight,
      \.namedRowHeight, \.tabHeight, \.indent,
    ] {
      #expect(small[keyPath: keyPath] < large[keyPath: keyPath])
    }
  }

  @Test func rowsAreTallEnoughForTheirText() {
    for size in stride(from: 10.0, through: 18.0, by: 1) {
      let metrics = UIMetrics(fontSize: size)
      #expect(metrics.rowHeight >= metrics.body * 1.8, "size \(size)")
      #expect(
        metrics.namedRowHeight >= metrics.rowHeight + metrics.badge,
        "a named row holds a branch line under the name at \(size)")
      #expect(metrics.badge >= 7, "badge text must stay legible at \(size)")
    }
  }

  /// A tab's floor has to leave room for what a tab always draws: side
  /// padding, a state dot or an icon, the gap after it, and the close
  /// button, with something over for the title. Below that the glyphs run
  /// into each other, which is what the strip scrolls to avoid.
  @Test func theNarrowestTabStillHasRoomForItsTitle() {
    for size in stride(from: 10.0, through: 18.0, by: 1) {
      let metrics = UIMetrics(fontSize: size)
      let furniture = 20.0 + metrics.icon + 7 + 20
      #expect(
        metrics.tabMinWidth >= furniture + metrics.body * 2,
        "no room for a title at \(size)")
      #expect(metrics.tabMinWidth < metrics.tabMaxWidth, "size \(size)")
      #expect(metrics.newTabWidth >= metrics.icon * 2, "the plus needs a target at \(size)")
      #expect(
        metrics.tabArrowWidth >= metrics.body,
        "the scroll arrow's own glyph does not fit at \(size)")
      #expect(
        metrics.tabMinWidth > 2 * metrics.tabArrowWidth,
        "two gutters must leave room for a tab at \(size)")
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

@Suite @MainActor
struct InstalledFontsTests {
  /// Refresh has to replace the cache, not just the view: the `@State`
  /// default reads it again each time the settings window opens.
  @Test func refreshReplacesTheCacheAndNotJustTheView() {
    #expect(!InstalledFonts.all.monospaced.isEmpty, "this Mac has a monospaced font")
    let reloaded = InstalledFonts.reload()
    #expect(reloaded == InstalledFonts.all)
  }
}
