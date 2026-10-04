import AppKit
import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyColorSchemeTests {
  @Test func aDarkAppearanceIsADarkScheme() throws {
    let dark = try #require(NSAppearance(named: .darkAqua))
    #expect(GhosttyColorScheme.scheme(for: dark) == GHOSTTY_COLOR_SCHEME_DARK)
  }

  @Test func aLightAppearanceIsALightScheme() throws {
    let light = try #require(NSAppearance(named: .aqua))
    #expect(GhosttyColorScheme.scheme(for: light) == GHOSTTY_COLOR_SCHEME_LIGHT)
  }
}
