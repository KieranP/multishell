import Testing

@testable import MultishellCore

@Suite
struct ControlKeyTests {
  @Test func aKeyIsReadWithItsModifiersAsItIsSpelled() throws {
    let interrupt = try #require(ControlKey(parsing: "ctrl-c"))
    #expect(interrupt.key == "c" && interrupt.modifiers == [.control])
    let back = try #require(ControlKey(parsing: "Shift-Tab"))
    #expect(back.key == "tab" && back.modifiers == [.shift])
    #expect(ControlKey(parsing: "escape")?.modifiers == [])
    #expect(ControlKey(parsing: "ctrl--")?.key == "-")
    #expect(ControlKey(parsing: "-")?.key == "-")
  }

  @Test func aCapitalLetterOnItsOwnIsThatLetterWithShift() throws {
    let capital = try #require(ControlKey(parsing: "A"))
    #expect(capital.key == "a" && capital.modifiers == [.shift])
  }

  @Test func aCapitalAfterAModifierIsTheLetterAsSpelledInEitherCase() {
    #expect(ControlKey(parsing: "Ctrl-C") == ControlKey(parsing: "ctrl-c"))
    #expect(ControlKey(parsing: "ctrl-shift-A")?.modifiers == [.control, .shift])
  }

  @Test func aKeyOrModifierItDoesNotKnowIsNoKey() {
    for text in ["", "ctrl-", "hyper-c", "f13", "ab", "ctrl-shift", "ctrl-ctrl-c"] {
      #expect(ControlKey(parsing: text) == nil, "\(text)")
    }
  }
}
