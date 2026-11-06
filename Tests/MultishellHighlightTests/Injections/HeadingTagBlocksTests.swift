import Foundation
import MultishellAppCore
import Testing

@testable import MultishellHighlight

@Suite
struct HeadingTagBlocksTests {
  @Test func aHeadingTagWithTextAfterItOnItsLineIsReadAsAnHTMLBlock() {
    let text = "<p>\n</p>\n\n<h1 align=\"center\">Multishell</h1>\n\nText.\n"
    let spans = HighlightProbe.spans(in: text, language: .markdown)
    let prose = (text as NSString).range(of: "Text.").integerRange

    #expect(HighlightProbe.role(of: "h1", in: text, spans: spans) == .keyword)
    #expect(HighlightProbe.role(of: "align", in: text, spans: spans) == .attribute)
    #expect(spans.contains { $0.range.overlaps(prose) } == false)
  }

  @Test func aQuotedHeadingTagBlockHasItsMarkersBlankedAndKeepsTheirColour() {
    let text = "> <h2 id=\"a\">Title</h2>\n> <b class=\"x\">more</b>\n"
    let spans = HighlightProbe.spans(in: text, language: .markdown)
    let secondMarker = (text as NSString).range(of: "> <b").location

    #expect(HighlightProbe.role(of: "class", in: text, spans: spans) == .attribute)
    #expect(spans.last { $0.range.contains(secondMarker) }?.role == .punctuation)
  }

  @Test func aHeadingTagLineInterruptingAParagraphIsReadAsHTMLFromThatLine() throws {
    let text = "Intro text\n<h2 align=\"center\">Multishell</h2>\n"
    let found = try InjectionProbe.injections(in: text, language: .markdown)
    let tag = (text as NSString).range(of: "<h2").location

    #expect(found.map(\.range.lowerBound) == [tag])
    #expect(HighlightProbe.role(of: "align", in: text, language: .markdown) == .attribute)
  }

  @Test func aQuotedHeadingTagLineInterruptingAParagraphKeepsItsMarkersColour() {
    let text = "> Intro\n> <h2 class=\"x\">T</h2>\n> <b id=\"y\">more</b>\n"
    let spans = HighlightProbe.spans(in: text, language: .markdown)
    let lastMarker = (text as NSString).range(of: "> <b").location

    #expect(HighlightProbe.role(of: "class", in: text, spans: spans) == .attribute)
    #expect(HighlightProbe.role(of: "id", in: text, spans: spans) == .attribute)
    #expect(spans.last { $0.range.contains(lastMarker) }?.role == .punctuation)
  }

  @Test func aQuotedHeadingTagBlockBlanksTheMarkerOfTheLineAfterIt() throws {
    let text = "> <h2 a=\"b\">T</h2>\n> - item\n"
    let found = try InjectionProbe.injections(in: text, language: .markdown)

    #expect(found.map { $0.source(in: text as NSString) } == ["<h2 a=\"b\">T</h2>\n  "])
  }

  @Test func aHeadingTagBlockLeftOpenKeepsTheQuoteMarkersInsideItsColour() {
    let text = "> <h2>T</h2> <!--\n> <div>\n> -->\n"
    let spans = HighlightProbe.spans(in: text, language: .markdown)
    let secondMarker = (text as NSString).range(of: "> <div").location

    #expect(spans.last { $0.range.contains(secondMarker) }?.role == .punctuation)
  }

  @Test func aHeadingTagLineAboveASetextUnderlineIsReadAsHTML() {
    let text = "<h2 a=\"b\">T</h2>\n---\n"

    #expect(HighlightProbe.role(of: "h2", in: text, language: .markdown) == .keyword)
  }

  @Test func aHeadingTagInAFenceStaysTheFencesTextAndOneAfterItIsStillFound() {
    let text = "```\n<h2 c=\"d\">U</h2>\n```\n\n<h3 e=\"f\">V</h3>\n"
    let spans = HighlightProbe.spans(in: text, language: .markdown)

    #expect(HighlightProbe.role(of: "c", in: text, spans: spans) != .attribute)
    #expect(HighlightProbe.role(of: "e", in: text, spans: spans) == .attribute)
  }

  @Test func aHeadingTagOpeningAListItemIsReadAsAnHTMLBlock() {
    let text = "- <h2 class=\"x\">T</h2>\n"

    #expect(HighlightProbe.role(of: "class", in: text, language: .markdown) == .attribute)
  }

  @Test(arguments: [
    "Use <h1> here.\n", "<h7 a>b</h7>\n", "<h1x a>b</h1x>\n", "a\nThen <h1 b>c</h1>\n",
    "Intro\n    <h1 a=\"b\">T</h1>\n", "Intro\n\t<h1 a=\"b\">T</h1>\n",
    "- a\n      <h2 a=\"b\">T</h2>\n", "> a\n>\t  <h2 b=\"c\">T</h2>\n",
    "- a\n \t  <h2 b=\"c\">T</h2>\n",
  ])
  func aParagraphNotOpeningWithAHeadingTagStaysMarkdown(text: String) throws {
    #expect(try InjectionProbe.injections(in: text, language: .markdown).isEmpty)
  }

  @Test(
    .timeLimit(.minutes(1)),
    arguments: [
      "> start\n" + String(repeating: "> Use <h1> and <h2> here, and <h3> too.\n", count: 10_000),
      "x" + String(repeating: " <h1>", count: 64_000) + "\n",
    ],
  )
  func aParagraphMentioningHeadingTagsMidLineHighlightsWithinAMinute(text: String) {
    #expect(
      HighlightProbe.spans(in: text, language: .markdown).contains { $0.role == .keyword } == false
    )
  }

  @Test(arguments: [
    "> Intro\n> \t<h2 a=\"b\">T</h2>\n", "- a\n  \t<h2 a=\"b\">T</h2>\n",
    "> \t<h2 a=\"b\">T</h2>\n", "- a\n\n  \t<h2 a=\"b\">T</h2>\n",
  ])
  func aTabFillingUnderFourColumnsPastTheLinesMarkerStillOpensABlock(text: String) {
    #expect(HighlightProbe.role(of: "h2", in: text, language: .markdown) == .keyword)
  }
}
