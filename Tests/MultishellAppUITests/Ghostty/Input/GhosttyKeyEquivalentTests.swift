import AppKit
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyKeyEquivalentTests {
  @Test func aCommandKeyIsLeftToTheMenusOnItsFirstOfferAndTypedOnItsSecond() {
    var equivalent = GhosttyKeyEquivalent()
    let first = equivalent.offer("k", characters: "k", flags: .command, timestamp: 5)
    #expect(first == nil)
    #expect(equivalent.isSecondOffer(at: 5))

    let second = equivalent.offer("k", characters: "k", flags: .command, timestamp: 5)
    #expect(second == "k")
    #expect(!equivalent.isSecondOffer(at: 5))
  }

  @Test func aNewKeyStartsOverRatherThanTypingOnTheOldKeysOffer() {
    var equivalent = GhosttyKeyEquivalent()
    _ = equivalent.offer("k", characters: "k", flags: .command, timestamp: 5)
    #expect(equivalent.offer("j", characters: "j", flags: .command, timestamp: 6) == nil)
    #expect(equivalent.isSecondOffer(at: 6))
  }

  @Test func aKeyWithoutCommandOrControlEndsWhateverWasOnOffer() {
    var equivalent = GhosttyKeyEquivalent()
    _ = equivalent.offer("k", characters: "k", flags: .command, timestamp: 5)
    #expect(equivalent.offer("k", characters: "k", flags: .option, timestamp: 5) == nil)
    #expect(!equivalent.isSecondOffer(at: 5))
  }

  @Test func aSyntheticKeyIsLeftAloneAndRemembersNothing() {
    var equivalent = GhosttyKeyEquivalent()
    #expect(
      equivalent.offer("\u{1B}", characters: "\u{1B}", flags: .command, timestamp: 0) == nil
    )
    #expect(!equivalent.isSecondOffer(at: 0))
  }

  @Test func controlReturnIsTypedAtOnceAndPlainReturnLeftToAppKit() {
    var equivalent = GhosttyKeyEquivalent()
    #expect(equivalent.offer("\r", characters: "\r", flags: .control, timestamp: 5) == "\r")
    #expect(equivalent.offer("\r", characters: "\r", flags: [], timestamp: 5) == nil)
  }

  @Test func controlSlashIsControlUnderscoreButNotWithAnotherModifier() {
    var equivalent = GhosttyKeyEquivalent()
    #expect(equivalent.offer("/", characters: "/", flags: .control, timestamp: 5) == "_")
    #expect(
      equivalent.offer("/", characters: "/", flags: [.control, .shift], timestamp: 5) == nil
    )
  }

  @Test func resettingEndsTheOffer() {
    var equivalent = GhosttyKeyEquivalent()
    _ = equivalent.offer("k", characters: "k", flags: .command, timestamp: 5)
    equivalent.reset()
    #expect(!equivalent.isSecondOffer(at: 5))
  }
}
