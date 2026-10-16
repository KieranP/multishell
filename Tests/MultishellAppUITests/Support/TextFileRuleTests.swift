import Foundation
import MultishellAppCore
import Testing

@testable import MultishellAppUI

@Suite
struct TextFileRuleTests {
  @Test func aGoneFileOpensByItsTypeOrByAStartThatReadsAsText() {
    #expect(TextFileRule.opensAsText(named: "notes.txt", startingWith: Data([0x00])))
    #expect(TextFileRule.opensAsText(named: "Dockerfile", startingWith: Data("FROM x\n".utf8)))
    #expect(!TextFileRule.opensAsText(named: "logo.png", startingWith: Data([0x89, 0x50, 0x00])))
  }

  @Test func aStartCutMidCharacterAtTheCheckedLengthStillReadsAsText() {
    let text = String(repeating: "a", count: TextFileStart.byteCount - 1) + "é"
    let cut = Data(text.utf8).prefix(TextFileStart.byteCount)

    #expect(TextFileRule.opensAsText(named: "data", startingWith: cut))
  }
}
