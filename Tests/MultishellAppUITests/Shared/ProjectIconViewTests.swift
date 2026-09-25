import AppKit
import Testing

@testable import MultishellCore

@Suite
struct ProjectIconViewTests {
  /// A misspelled SF Symbol draws nothing. macOS 26 availability is checked against
  /// CoreGlyphs' data when a symbol is added, not here, since the test machine is newer.
  @Test func everySymbolInThePaletteExists() {
    for name in ProjectIcon.symbols {
      #expect(
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil,
        "no SF Symbol called \(name)")
    }
  }

  /// The sidebar's unclipped 17pt square lets wider symbols spill toward the name. Eight
  /// of the 59 the app first shipped already did, the widest at 22, so 22 is the cap.
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
