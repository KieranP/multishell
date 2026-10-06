import AppKit
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct NSEventKeyCopyTests {
  @Test func aCopyTakesTheNewTextAndKeepsTheKeyAndItsTimestamp() throws {
    let event = try keyDown("/", keyCode: 0x2C, flags: .control)
    let copy = try #require(event.keyCopy(characters: "_", charactersIgnoringModifiers: "_"))
    #expect(copy.characters == "_")
    #expect(copy.keyCode == event.keyCode)
    #expect(copy.timestamp == event.timestamp)
    #expect(copy.modifierFlags == event.modifierFlags)
  }

  @Test func aCopyWithOtherModifiersTakesThem() throws {
    let event = try keyDown("a", keyCode: 0x00, flags: .option)
    let copy = try #require(
      event.keyCopy(modifierFlags: [], characters: "a", charactersIgnoringModifiers: "a"))
    #expect(copy.modifierFlags.contains(.option) == false)
    #expect(copy.timestamp == event.timestamp)
  }
}
