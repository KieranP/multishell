import Foundation
import MultishellAppCore
import SwiftTreeSitter
import Testing

@testable import MultishellHighlight

@Suite
struct HighlightInjectionsSvelteTests {
  @Test func aSvelteExpressionInTextOrAnAttributeIsHighlighted() {
    let text = "<p class={\"big\"}>{count + 2}</p>\n{#if count > 3}<b/>{/if}"

    #expect(HighlightProbe.role(of: "\"big\"", in: text, language: .svelte) == .string)
    #expect(HighlightProbe.role(of: "2", in: text, language: .svelte) == .number)
    #expect(HighlightProbe.role(of: "3", in: text, language: .svelte) == .number)
  }

  @Test func anEachBlocksKeyIsReadApartFromItsIndex() {
    let text = "{#each rows as row, n (row.key || 7)}<li/>{/each}"

    #expect(HighlightProbe.role(of: "n", in: text, language: .svelte) == .plain)
    #expect(HighlightProbe.role(of: "7", in: text, language: .svelte) == .number)
  }

  @Test(arguments: [
    "{#each items as { id, qty = 1 }, i (id)}<li/>{/each}",
    "{#each pairs as [a, b = 2]}<li/>{/each}",
    "{#await p then { data = [] }}{/await}",
    "{#await p}{:then { data = [] }}{/await}",
    "{#await p}{:catch { message = \"\" }}{/await}",
  ])
  func aBlocksDestructuredPatternWithADefaultParsesWithoutError(text: String) throws {
    let injections = try InjectionProbe.injections(in: text, language: .svelte)
    let source = text as NSString

    #expect(!injections.isEmpty)
    for injection in injections {
      let parser = Parser()
      try parser.setLanguage(HighlightGrammars.compile(injection.language).language)
      let body = source.substring(with: NSRange(injection.range))
      let parsed = try #require(WrappedInjection.parsed(body, in: injection, parser: parser))
      #expect(parsed.tree.rootNode?.hasError == false, "\(parsed.text)")
    }
  }

  @Test func aThenNamedInsideAnAwaitsPromiseIsNotItsKeyword() {
    let text = "{#await ready ? then : other}{/await}"

    #expect(HighlightProbe.role(of: "then", in: text, language: .svelte) == .plain)
  }

  @Test func anAwaitBlocksThenOrCatchIsAKeywordBetweenThePromiseAndItsName() {
    let then = "{#await load() then value}{value}{/await}"
    let failure = "{#await load() catch err}{err}{/await}"

    #expect(HighlightProbe.role(of: "then", in: then, language: .svelte) == .keyword)
    #expect(HighlightProbe.role(of: "load", in: then, language: .svelte) == .function)
    #expect(HighlightProbe.role(of: "catch", in: failure, language: .svelte) == .keyword)
  }

  @Test(arguments: [
    "", "<script>let a, b, c;</script>\n", "<script lang=\"typescript\"></script>",
    "<script lang = \"ts\"></script>", "<SCRIPT lang=\"ts\"></SCRIPT>",
    "<!-- <script lang=\"ts\"></script> -->",
  ])
  func aSvelteExpressionIsJavaScriptUnlessSveltesLangRegexFindsTS(script: String) {
    let text = "{a < b > (c)}\n" + script

    #expect(HighlightProbe.role(of: "a", in: text, language: .svelte) != .function)
    #expect(HighlightProbe.role(of: "b", in: text, language: .svelte) != .type)
  }

  @Test func aLangInsideAnEarlierAttributesValueIsMissedThoughSveltesRegexFindsIt() {
    let text = "{a < b > (c)}\n<script x=\">\" a=\"b lang=ts\" c></script>"

    #expect(HighlightProbe.role(of: "b", in: text, language: .svelte) != .type)
  }

  @Test(arguments: [
    "<script lang=\"ts x\"></script>\n<script lang=\"ts\"></script>",
    "<script data-lang=\"ts\"></script>",
  ])
  func aSvelteExpressionIsTypeScriptWhereSveltesLangRegexFindsTS(script: String) {
    let text = "{a < b > (c)}\n" + script

    #expect(HighlightProbe.role(of: "b", in: text, language: .svelte) == .type)
  }

  @Test func aScriptTagWithEachAttributeOnAnIndentedLineIsReadWithoutBacktrackingForever() {
    let attributes = (0..<30).map { "\n    a\($0)=\"v\"" }.joined()
    let text = "<script\(attributes)\n></script>\n<script lang=\"ts\"></script>" as NSString

    #expect(HighlightInjections.expressionLanguage(in: text) == .typeScript)
  }

  @Test func aSvelteExpressionIsTypeScriptWhereTheFirstLangTheRegexFindsIsTS() {
    let text = "<script module>let f;</script>\n<script lang=\"ts\"></script>\n{a < b > (c)}"

    #expect(HighlightProbe.role(of: "b", in: text, language: .svelte) == .type)
  }

  @Test func aSvelteExpressionIsJavaScriptWhereTheFirstLangTheRegexFindsIsNotTS() {
    let text = "{a < b > (c)}\n<script module lang=\"js\"></script>\n<script lang=\"ts\"></script>"

    #expect(HighlightProbe.role(of: "b", in: text, language: .svelte) != .type)
  }

  @Test func aSnippetsNameAndParameterTypesAreHighlighted() {
    let text = "<script lang=\"ts\"></script>{#snippet row(a: number)}<td/>{/snippet}"

    #expect(HighlightProbe.role(of: "row", in: text, language: .svelte) == .function)
    #expect(HighlightProbe.role(of: "number", in: text, language: .svelte) == .type)
  }

  @Test func anAwaitsThenRightAfterThePromiseIsItsKeyword() {
    let text = "{#await f()then v}{v}{/await}"

    #expect(HighlightProbe.role(of: "then", in: text, language: .svelte) == .keyword)
  }

  @Test func aSvelteExpressionInBracesIsAnObjectNotABlock() {
    let text = "<Item props={{class: \"x\"}} />"

    #expect(HighlightProbe.role(of: "class", in: text, language: .svelte) == .plain)
  }

  @Test func aShorthandAttributeKeepsItsAttributeColour() {
    let text = "<input {value}>"

    #expect(HighlightProbe.role(of: "value", in: text, language: .svelte) == .attribute)
  }

  @Test func aSvelteExpressionInAKeptRangeTakesTheLangOfAScriptOutsideIt() throws {
    let text = "<script lang=\"ts\"></script>\n{f<Row>(c)}"

    let found = try InjectionProbe.injections(
      in: text,
      language: .svelte,
      within: [InjectionProbe.range(ofLine: 1, in: text)],
    )

    #expect(found.map(\.language) == [.typeScript])
  }
}
