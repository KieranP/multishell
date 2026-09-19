import AppKit
import MultishellCore
import Testing

@Suite
struct ProjectIconSymbolTests {
  /// A misspelled SF Symbol name draws nothing at all, and the palette is
  /// hundreds of names typed by hand. This catches the typo; that a name
  /// exists as far back as macOS 14 is checked against CoreGlyphs' own
  /// availability data when a symbol is added, not here, since the test
  /// machine's OS is newer.
  @Test func everySymbolInThePaletteExists() {
    for name in ProjectIcon.symbols {
      #expect(
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil,
        "no SF Symbol called \(name)")
    }
  }

  /// The sidebar draws a symbol in a square of `UIMetrics.icon + 6`, which
  /// is 17 points at the default font size, and SwiftUI does not clip it: a
  /// symbol wider than that spills into the gap before the project's name.
  /// Most SF Symbols wider than they are tall do, and eight of the fifty-nine
  /// the app shipped with already did, the widest at 22. So the rule is no
  /// worse than what has always been drawn, measured rather than guessed.
  @Test func noSymbolIsWiderThanTheWidestTheSidebarAlreadyDrew() {
    let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
    for name in ProjectIcon.symbols {
      guard
        let sized = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
          .withSymbolConfiguration(configuration)
      else { continue }
      #expect(sized.size.width <= 22, "\(name) draws \(sized.size.width) wide in a 17 wide square")
    }
  }
}
