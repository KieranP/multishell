import AppKit
import Foundation
import SwiftUI
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct ThemeChromeColorsTests {
  @Test func theFadeOverAPaneIsOpaqueAsTheTerminalUnderItIs() throws {
    let theme = try JSONDecoder().decode(
      Theme.self,
      from: Data(##"{ "id": "x", "name": "X", "terminal": { "background": "#10203080" } }"##.utf8),
    )
    let fade = try theme.terminalBackground.inSRGB()
    #expect(fade.alphaComponent == 1)
    #expect(Int((fade.redComponent * 255).rounded()) == 0x10)
  }
}
