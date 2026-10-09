import Foundation
import Testing

@testable import MultishellCore

struct AppearanceTests {
  @Test func anAppearanceWithoutAUIFontSizeGetsTheDefault() throws {
    let appearance = try decodeJSON(
      Appearance.self,
      #"{ "themeID": "multishell.light", "fontSize": 15 }"#,
    )
    #expect(appearance.themeID == "multishell.light")
    #expect(appearance.terminalFontSize == 15)
    #expect(appearance.uiFontSize == Appearance.defaultUIFontSize)
    #expect(appearance.terminalFontName == nil)
  }

  @Test func theTerminalFontIsReadAndWrittenUnderTheKeysEarlierBuildsWrote() throws {
    let saved = try decodeJSON(Appearance.self, #"{ "fontName": "Menlo", "fontSize": 15 }"#)
    #expect(saved.terminalFontName == "Menlo")
    #expect(saved.terminalFontSize == 15)

    let written = try JSONSerialization.jsonObject(with: JSONEncoder().encode(saved))
    #expect((written as? [String: Any])?["fontName"] as? String == "Menlo")
    #expect((written as? [String: Any])?["fontSize"] as? Double == 15)
  }

  @Test func aMissingThemeFallsBackToDark() {
    var appearance = Appearance()
    appearance.themeID = "gone"
    #expect(appearance.theme() == .multishellDark)
  }
}
