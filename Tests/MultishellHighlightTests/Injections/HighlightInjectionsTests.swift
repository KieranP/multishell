import Foundation
import MultishellAppCore
import Testing

@testable import MultishellHighlight

@Suite
struct HighlightInjectionsTests {
  @Test func aSvelteScriptIsHighlightedAsJavaScript() {
    let text = "<script>\n  let count = 1;\n</script>\n<p>hi</p>"

    #expect(HighlightProbe.role(of: "let", in: text, language: .svelte) == .keyword)
    #expect(HighlightProbe.role(of: "1", in: text, language: .svelte) == .number)
  }

  @Test func aSvelteScriptMarkedTypeScriptIsHighlightedAsTypeScript() {
    let text = "<script lang=\"ts\">\n  interface Props { a: string }\n</script>"

    #expect(HighlightProbe.role(of: "interface", in: text, language: .svelte) == .keyword)
  }

  @Test func aSvelteStyleIsHighlightedAsCSS() {
    let text = "<p>hi</p>\n<style>\n  p { width: 10px; }\n</style>"

    #expect(HighlightProbe.role(of: "10", in: text, language: .svelte) == .number)
  }

  @Test func aStylesPropertyNamesAreColouredInlineAndInSCSS() {
    let inline = "<div style=\"color: red\"></div>"
    let scss = "<style lang=\"scss\">$a: 1px; p { width: $a; }</style>"

    #expect(HighlightProbe.role(of: "color", in: inline, language: .svelte) == .attribute)
    #expect(HighlightProbe.role(of: "width", in: scss, language: .svelte) == .attribute)
  }

  @Test func anHTMLScriptAndStyleAreHighlightedInTheirLanguages() {
    let text = "<style>p { width: 10px; }</style>\n<script>const a = 1;</script>"

    #expect(HighlightProbe.role(of: "const", in: text, language: .html) == .keyword)
    #expect(HighlightProbe.role(of: "10", in: text, language: .html) == .number)
  }

  @Test func anEmptyScriptOrStyleIsNotInjected() throws {
    let text = "<script src=\"a.js\"></script><style></style><script> </script>"
    let languages = try InjectionProbe.languages(in: text)

    #expect(languages == [.javaScript])
  }

  @Test func aSvelteScriptNestedInMarkupFollowsSvelteRules() {
    let nested = "<div><script lang=\"ts\">interface A {}</script></div>"

    #expect(HighlightProbe.role(of: "interface", in: nested, language: .svelte) == .keyword)
  }

  @Test func aSvelteScriptBelowAnUnclosedBlockKeepsItsLang() {
    let text = "{#if a}\n<p>x</p>\n<script lang=\"ts\">\ninterface Foo {}\n</script>"

    #expect(HighlightProbe.role(of: "interface", in: text, language: .svelte) == .keyword)
  }

  @Test func aSvelteStyleInSCSSIsHighlightedAsSCSS() {
    let text = "<style lang=\"scss\">\n  $gap: 4px;\n  p { color: red; }\n</style>"

    #expect(HighlightProbe.role(of: "4", in: text, language: .svelte) == .number)
    #expect(HighlightProbe.role(of: "red", in: text, language: .svelte) == .string)
  }

  @Test func aLessStyleIsLeftPlain() {
    let text = "<style lang=\"less\">p { width: 10px; }</style>"

    #expect(HighlightProbe.role(of: "10", in: text, language: .svelte) ?? .plain == .plain)
  }

  @Test func anInjectedSpanCountsFromTheStartOfTheWholeFile() {
    let text = "<p>🙂</p><script>const a = 1;</script>"
    let spans = HighlightProbe.spans(in: text, language: .svelte)
    let keyword = (text as NSString).range(of: "const")

    #expect(
      spans.contains { span in
        span.role == .keyword && span.range == keyword.integerRange
      }
    )
  }

  @Test func onlyTheInjectionsReachingAKeptRangeAreFound() throws {
    let text = "<script>var a</script>\n<p onclick=\"go()\">x</p>\n<script>let b</script>"

    let found = try InjectionProbe.injections(
      in: text,
      within: [InjectionProbe.range(ofLine: 2, in: text)],
    )

    #expect(found.map(\.range) == [(text as NSString).range(of: "let b").integerRange])
  }

  @Test func anElementSpanningTwoKeptRangesIsFoundOnce() throws {
    let text = "<script>\nvar a\nvar b\nvar c\n</script>"
    let kept = [
      InjectionProbe.range(ofLine: 1, in: text), InjectionProbe.range(ofLine: 3, in: text),
    ]

    #expect(try InjectionProbe.injections(in: text, within: kept).count == 1)
  }
}
