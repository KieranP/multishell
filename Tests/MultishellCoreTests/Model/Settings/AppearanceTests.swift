import Foundation
import Testing

@testable import MultishellCore

struct AppearanceTests {
  @Test func anAppearanceWithoutAUIFontSizeGetsTheDefault() throws {
    let appearance = try decodeJSON(
      Appearance.self, #"{ "themeID": "multishell.light", "fontSize": 15 }"#)
    #expect(appearance.themeID == "multishell.light")
    #expect(appearance.fontSize == 15)
    #expect(appearance.uiFontSize == Appearance.defaultUIFontSize)
    #expect(appearance.fontName == nil)
  }

  @Test func aMissingThemeFallsBackToDark() {
    var appearance = Appearance()
    appearance.themeID = "gone"
    #expect(appearance.theme() == .multishellDark)
  }
}
