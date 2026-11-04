import Testing

@testable import MultishellAppCore

@Suite
struct GlyphButtonLightTests {
  @Test func aButtonIsLitOnlyUnderThePointer() {
    #expect(GlyphButtonLight.isLit(isHovered: true, isEnabled: true))
    #expect(!GlyphButtonLight.isLit(isHovered: false, isEnabled: true))
  }

  @Test func aDisabledButtonStaysUnlitUnderThePointer() {
    #expect(!GlyphButtonLight.isLit(isHovered: true, isEnabled: false))
  }

  @Test func aToggleThatIsOnKeepsItsColourWhenLitAndOneOffTurnsToText() {
    #expect(!GlyphButtonLight.turnsToTextWhenLit(isOn: true))
    #expect(GlyphButtonLight.turnsToTextWhenLit(isOn: false))
  }
}
