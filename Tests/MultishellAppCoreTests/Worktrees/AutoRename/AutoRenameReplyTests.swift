import Testing

@testable import MultishellAppCore

@Suite
struct AutoRenameReplyTests {
  @Test func aPlainReplyIsTheName() {
    #expect(AutoRenameReply.name(from: "Billing export\n") == "Billing export")
  }

  @Test func onlyTheFirstLineWithWordsIsTaken() {
    #expect(
      AutoRenameReply.name(from: "\n\n  Billing export  \nThis branch adds CSV export.")
        == "Billing export"
    )
  }

  @Test(arguments: [
    "\"Billing export\"", "'Billing export'", "“Billing export”", "`Billing export`",
    "**Billing export**", "*Billing export*", "# Billing export", "- Billing export",
    "1. Billing export", "Name: Billing export", "Billing export.", "« Billing export »",
    "\"Billing export\".", "**\"Billing export\"**",
  ])
  func quotesMarkdownALabelAndAFullStopGo(reply: String) {
    #expect(AutoRenameReply.name(from: reply) == "Billing export")
  }

  @Test func underscoresInsideAWordStay() {
    #expect(AutoRenameReply.name(from: "Fix retry_after parsing") == "Fix retry_after parsing")
  }

  @Test func runsOfSpaceInsideTheNameBecomeOne() {
    #expect(AutoRenameReply.name(from: "Billing\t  export") == "Billing export")
  }

  @Test func aLongReplyIsCutAtAWordWithinTheBound() throws {
    let reply = "Rework the billing export so finance can pull monthly CSV reports quickly"
    let name = try #require(AutoRenameReply.name(from: reply))
    #expect(name.count <= AutoRenameReply.maximumLength)
    #expect(reply.hasPrefix(name))
    #expect(!name.hasSuffix(" "))
    #expect(reply.dropFirst(name.count).first == " ", "cut between words")
  }

  @Test func aLongWordWithNoSpaceIsCutAtTheBound() throws {
    let name = try #require(AutoRenameReply.name(from: String(repeating: "x", count: 200)))
    #expect(name.count == AutoRenameReply.maximumLength)
  }

  @Test(arguments: ["", "  \n\n", "\"\"", "**", "Name:"])
  func aReplyWithNoWordsIsNoName(reply: String) {
    #expect(AutoRenameReply.name(from: reply) == nil)
  }

  @Test func aLineOfOnlyMarksIsSkippedForTheNextWithWords() {
    #expect(AutoRenameReply.name(from: "```\nBilling export\n```") == "Billing export")
    #expect(AutoRenameReply.name(from: "***\nBilling export") == "Billing export")
    #expect(AutoRenameReply.name(from: "---\nBilling export") == "Billing export")
  }

  @Test func escapeSequencesAndControlCharactersGo() {
    #expect(
      AutoRenameReply.name(from: "\u{1b}[1mBilling export\u{1b}[0m\u{7}") == "Billing export"
    )
  }

  @Test func marksInsideTheNameStay() {
    #expect(AutoRenameReply.name(from: "Fix __init__ handling") == "Fix __init__ handling")
    #expect(AutoRenameReply.name(from: "Pass **kwargs through") == "Pass **kwargs through")
  }

  @Test func twoQuotedPhrasesKeepTheirQuotes() {
    #expect(AutoRenameReply.name(from: "\"Foo\" and \"Bar\"") == "\"Foo\" and \"Bar\"")
  }

  @Test func aHyperlinkEndedByStringTerminatorGoesWhole() {
    #expect(
      AutoRenameReply.name(from: "\u{1b}]8;;https://x\u{1b}\\Billing export\u{1b}]8;;\u{1b}\\")
        == "Billing export"
    )
  }

  @Test func aFenceWithALanguageIsNotTheName() {
    #expect(AutoRenameReply.name(from: "```text\nBilling export\n```") == "Billing export")
  }

  @Test func aBoldLabelGoesWithItsMarks() {
    #expect(AutoRenameReply.name(from: "**Name:** Billing export") == "Billing export")
    #expect(AutoRenameReply.name(from: "__Name__: Billing export") == "Billing export")
  }

  @Test func aCharacterSetEscapeGoesWhole() {
    #expect(AutoRenameReply.name(from: "Billing export\u{1b}(B\u{1b}[m") == "Billing export")
  }

  @Test func joinersAndDirectionMarksStay() {
    #expect(AutoRenameReply.name(from: "👩‍💻 Dev tools") == "👩‍💻 Dev tools")
    #expect(AutoRenameReply.name(from: "\u{200F}שלום world") == "\u{200F}שלום world")
  }

  @Test(arguments: [
    "\u{1b}[38:2:255:0:0mBilling export\u{1b}[0m",
    "\u{1b}[>4;2mBilling export",
    "\u{1b}P1$r0m\u{1b}\\Billing export",
    "\u{1b}_application\u{1b}\\Billing export",
  ])
  func everyStandardEscapeGoesWhole(reply: String) {
    #expect(AutoRenameReply.name(from: reply) == "Billing export")
  }

  @Test func anApostropheInsideSingleQuotesLetsThemGo() {
    #expect(AutoRenameReply.name(from: "'Fix user's avatar upload'") == "Fix user's avatar upload")
    #expect(AutoRenameReply.name(from: "‘Fix user’s avatar’") == "Fix user’s avatar")
  }

  @Test(arguments: [
    "\u{1b}cBilling export", "\u{1b}#8Billing export", "\u{1b}%GBilling export",
  ])
  func anIndependentOrAnnouncerEscapeGoesWhole(reply: String) {
    #expect(AutoRenameReply.name(from: reply) == "Billing export")
  }
}
