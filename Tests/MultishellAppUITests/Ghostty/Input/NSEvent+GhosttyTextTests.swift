import AppKit
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct NSEventGhosttyTextTests {
  @Test func aFunctionKeyTypesNothing() throws {
    let f1 = try keyDown(String(UnicodeScalar(0xF704)!), keyCode: 0x7A)
    #expect(f1.ghosttyText == nil)
  }

  @Test func controlWithALetterTypesTheLetterForLibghosttyToControl() throws {
    let event = try keyDown("\u{3}", keyCode: 0x08, flags: .control)
    let letter = try #require(event.characters(byApplyingModifiers: []))
    #expect(event.ghosttyText == letter)
    #expect(letter.unicodeScalars.allSatisfy { $0.value >= 0x20 }, "a letter, not a control")
  }
}
