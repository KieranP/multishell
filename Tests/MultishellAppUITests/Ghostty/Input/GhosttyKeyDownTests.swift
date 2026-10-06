import AppKit
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyKeyDownTests {
  private let leftArrow: UInt16 = 0x7B
  private let rightArrow: UInt16 = 0x7C
  private let aKey: UInt16 = 0x00

  @Test func aPlainKeySendsItselfWithItsText() {
    let deliveries = GhosttyKeyDown.deliveries(
      wasComposing: false, isComposing: false, committed: [], characters: "a", keyText: "a",
      keyCode: aKey, flags: [])
    #expect(deliveries == [.key(text: "a", isComposing: false)])
  }

  @Test func aKeyThatStartsCompositionIsSentAsComposing() {
    let deliveries = GhosttyKeyDown.deliveries(
      wasComposing: false, isComposing: true, committed: [], characters: "k", keyText: "k",
      keyCode: 0x28, flags: [])
    #expect(deliveries == [.key(text: "k", isComposing: true)])
  }

  @Test func textAnInputMethodCommitsMidCompositionIsSentAsTextAlone() {
    let deliveries = GhosttyKeyDown.deliveries(
      wasComposing: true, isComposing: false, committed: ["日本"], characters: "\r",
      keyText: "\r", keyCode: 0x24, flags: [])
    #expect(deliveries == [.committed("日本")])
  }

  @Test func anArrowThatCommitsStillMovesTheCaretAfterTheText() {
    let deliveries = GhosttyKeyDown.deliveries(
      wasComposing: true, isComposing: false, committed: ["한"], characters: nil, keyText: nil,
      keyCode: rightArrow, flags: [])
    #expect(deliveries == [.committed("한"), .key(text: nil, isComposing: false)])
  }

  @Test func aLeftArrowThatCommitsMovesTheCaretOnlyWithAModifier() {
    let plain = GhosttyKeyDown.deliveries(
      wasComposing: true, isComposing: false, committed: ["한"], characters: nil, keyText: nil,
      keyCode: leftArrow, flags: [])
    #expect(plain == [.committed("한")])

    let shifted = GhosttyKeyDown.deliveries(
      wasComposing: true, isComposing: false, committed: ["한"], characters: nil, keyText: nil,
      keyCode: leftArrow, flags: .shift)
    #expect(shifted == [.committed("한"), .key(text: nil, isComposing: false)])
  }

  @Test func textCommittedWithNoCompositionBeforeIsTypedByTheKey() {
    let deliveries = GhosttyKeyDown.deliveries(
      wasComposing: false, isComposing: false, committed: ["é"], characters: "é", keyText: "é",
      keyCode: 0x0E, flags: .option)
    #expect(deliveries == [.key(text: "é", isComposing: false)])
  }

  @Test func aControlCharacterWhileComposingIsTheInputMethodsAndSendsNothing() {
    let deliveries = GhosttyKeyDown.deliveries(
      wasComposing: true, isComposing: true, committed: [], characters: "\u{8}", keyText: nil,
      keyCode: 0x33, flags: [])
    #expect(deliveries.isEmpty)
  }

  @Test func aControlCharacterOutsideCompositionIsSentAsTheKey() {
    let deliveries = GhosttyKeyDown.deliveries(
      wasComposing: false, isComposing: false, committed: [], characters: "\u{8}", keyText: nil,
      keyCode: 0x33, flags: [])
    #expect(deliveries == [.key(text: nil, isComposing: false)])
  }

  @Test func aCommittedControlCharacterIsDroppedAndTheRestKept() {
    let deliveries = GhosttyKeyDown.deliveries(
      wasComposing: true, isComposing: false, committed: ["\r", "か"], characters: "\r",
      keyText: "\r", keyCode: 0x24, flags: [])
    #expect(deliveries == [.committed("か")])
  }
}
