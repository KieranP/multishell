import Foundation
import MultishellAppCore
import Testing

@testable import MultishellHighlight

@Suite
struct HTMLBlocksTests {
  @Test func anHTMLBlockIsHighlightedAsHTML() {
    let text = "# Title\n\n<section align=\"center\">\n  Hello\n</section>\n\nText.\n"
    let spans = HighlightProbe.spans(in: text, language: .markdown)

    #expect(HighlightProbe.role(of: "section", in: text, spans: spans) == .keyword)
    #expect(HighlightProbe.role(of: "align", in: text, spans: spans) == .attribute)
    #expect(HighlightProbe.role(of: "center", in: text, spans: spans) == .string)
  }

  @Test func aCommentBlockIsHighlightedAsAnHTMLComment() {
    let text = "<!-- prettier-ignore -->\n\nText.\n"

    #expect(
      HighlightProbe.role(of: "prettier-ignore", in: text, language: .markdown) == .comment
    )
  }

  @Test func anHTMLBlockEndsAtABlankLineLeavingTheHeadingAfterItMarkdown() throws {
    let text = "<div>\n<b>a</b>\n</div>\n\n## Next\n"
    let found = try InjectionProbe.injections(in: text, language: .markdown)
    let heading = (text as NSString).range(of: "## Next").location

    #expect(found.map(\.language) == [.html])
    #expect(found.map(\.range.lowerBound) == [0])
    #expect(found.allSatisfy { $0.range.upperBound <= heading })
  }

  @Test func anHTMLBlockInAQuoteHasItsMarkersBlankedAndKeepsTheirColour() throws {
    let text = "> <div\n> class=\"a\">\n> </div>\n"
    let spans = HighlightProbe.spans(in: text, language: .markdown)
    let found = try InjectionProbe.injections(in: text, language: .markdown)
    let secondMarker = (text as NSString).range(of: "> class").location

    #expect(found.map { $0.source(in: text as NSString) } == ["<div\n  class=\"a\">\n  </div>\n"])
    #expect(HighlightProbe.role(of: "class", in: text, spans: spans) == .attribute)
    #expect(spans.last { $0.range.contains(secondMarker) }?.role == .punctuation)
  }

  @Test func anHTMLBlockEndingTheFileWithNoNewlineStaysWithinTheText() throws {
    let text = "Text.\n\n<div>a</div>"
    let found = try InjectionProbe.injections(in: text, language: .markdown)

    #expect(found.map(\.range.upperBound) == [text.utf16.count])
    #expect(HighlightProbe.role(of: "div", in: text, language: .markdown) == .keyword)
  }

  @Test func aClosingTagInALaterBlockClosesTheElementAnEarlierOneOpened() {
    let text = "<details>\n<summary>Hi</summary>\n\nBody **text**\n\n</details>\n"
    let spans = HighlightProbe.spans(in: text, language: .markdown)

    #expect(
      HighlightProbe.role(of: "details", in: text, spans: spans, searching: .backwards) == .keyword
    )
  }

  @Test func markdownBetweenHTMLBlocksKeepsItsOwnColours() {
    let text = "<details>\n\n- item\n\n```swift\nlet a = 1\n```\n\n</details>\n"
    let spans = HighlightProbe.spans(in: text, language: .markdown)

    #expect(HighlightProbe.role(of: "-", in: text, spans: spans) == .punctuation)
    #expect(HighlightProbe.role(of: "let", in: text, spans: spans) == .keyword)
  }

  @Test func aStringLeftOpenInOneBlockColoursNoMarkdownBeforeTheNext() {
    let text = "<p title=\"a\n\nProse\n\n<p title=\"b\">\n"
    let spans = HighlightProbe.spans(in: text, language: .markdown)
    let prose = (text as NSString).range(of: "Prose").integerRange

    #expect(spans.contains { $0.range.overlaps(prose) } == false)
  }

  @Test func aClosingTagInAKeptRangeIsReadWithTheBlockThatOpenedItAbove() {
    let text = "<table>\n<tr>\n\n**a**\n\n</tr>\n</table>\n"
    let closing = (text as NSString).range(of: "</table>").integerRange
    var cache = HighlightPassCache()
    let spans = SyntaxHighlighter.shared.spans(
      in: text,
      language: .markdown,
      cache: &cache,
      within: [closing],
    )

    #expect(
      HighlightProbe.role(of: "table", in: text, spans: spans, searching: .backwards) == .keyword
    )
  }

  @Test func aKeptRangeOnlyInTheMarkdownBetweenBlocksFindsNoHTML() throws {
    let text = "<p>\n</p>\n\nProse row\n\n<div>\n</div>\n"
    let prose = (text as NSString).range(of: "Prose row").integerRange

    #expect(try InjectionProbe.injections(in: text, language: .markdown, within: [prose]).isEmpty)
  }

  @Test(arguments: ["<![CDATA[\nx < y\n]]>\n", "<?php echo 1; ?>\n"])
  func aCDATAOrProcessingInstructionBlockKeepsMarkdownsColour(text: String) throws {
    #expect(try InjectionProbe.injections(in: text, language: .markdown).isEmpty)
  }

  @Test func aScriptInAnHTMLBlockIsHighlightedInItsLanguage() {
    let text = "<script>\nconst a = 1\n</script>\n"

    #expect(HighlightProbe.role(of: "const", in: text, language: .markdown) == .keyword)
  }
}
