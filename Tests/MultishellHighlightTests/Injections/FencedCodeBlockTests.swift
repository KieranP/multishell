import Foundation
import MultishellAppCore
import Testing

@testable import MultishellHighlight

@Suite
struct FencedCodeBlockTests {
  @Test func aFencedCodeBlockIsHighlightedInTheLanguageItNames() {
    let text = "# Setup\n\n```swift\nlet a = 1\n```\n"

    #expect(HighlightProbe.role(of: "let", in: text, language: .markdown) == .keyword)
    #expect(HighlightProbe.role(of: "1", in: text, language: .markdown) == .number)
  }

  @Test(arguments: [
    ("sh", "if true; then echo; fi", "if", HighlightLanguage.bash),
    ("shell", "if true; then echo; fi", "if", .bash),
    ("ts", "interface A {}", "interface", .typeScript),
    ("PY", "def f(): pass", "def", .python),
    ("rb", "def f; end", "def", .ruby),
    ("golang", "func main() {}", "func", .golang),
    ("c#", "class A {}", "class", .cSharp),
    ("yml", "a: true", "true", .yaml),
  ])
  func aFenceNamesItsLanguageByNameOrExtensionInAnyCase(
    name: String,
    code: String,
    word: String,
    language: HighlightLanguage,
  ) throws {
    let text = "```\(name)\n\(code)\n```"

    #expect(try InjectionProbe.languages(in: text, language: .markdown) == [language])
    #expect(HighlightProbe.role(of: word, in: text, language: .markdown) != .plain)
  }

  @Test func aFenceReadsOnlyTheFirstWordOfItsInfoString() throws {
    let text = "~~~js title=\"a.js\"\nconst a = 1\n~~~"

    #expect(try InjectionProbe.languages(in: text, language: .markdown) == [.javaScript])
    #expect(HighlightProbe.role(of: "const", in: text, language: .markdown) == .keyword)
  }

  @Test func aFenceWithNoLanguageOrAnUnknownOneIsNotInjected() throws {
    let text = "```\nlet a = 1\n```\n\n```text\nlet b = 2\n```\n"

    #expect(try InjectionProbe.injections(in: text, language: .markdown).isEmpty)
  }

  @Test(arguments: ["```swift\n```\n", "```swift\n```", "> ```py\n> ", "- ```py\n  "])
  func aFenceWithAnEmptyBodyIsNotInjected(text: String) throws {
    #expect(try InjectionProbe.injections(in: text, language: .markdown).isEmpty)
  }

  @Test func aMarkdownFenceIsNotInjectedSoNestedFencesNeverRecurse() throws {
    let text = "```md\n# Title\n```\n\n```markdown\n```md\n```"

    #expect(try InjectionProbe.injections(in: text, language: .markdown).isEmpty)
  }

  @Test func aThousandNestedMarkdownFencesHighlightWithoutOverflowingTheStack() {
    let text = String(repeating: "```md\n", count: 1_000)

    #expect(!HighlightProbe.spans(in: text, language: .markdown).isEmpty)
  }

  @Test func aFenceInABlockQuoteIsHighlightedInItsLanguage() {
    let text = "> ```python\n> def f():\n>     return 1\n> ```"
    let spans = HighlightProbe.spans(in: text, language: .markdown)

    #expect(HighlightProbe.role(of: "def", in: text, spans: spans) == .keyword)
    #expect(HighlightProbe.role(of: "return", in: text, spans: spans) == .keyword)
  }

  @Test(arguments: [
    "> ```yaml\n> name: a\n> on: push\n> enabled: true\n> ```\n",
    "1. Add\n\n   ```yaml\n   name: a\n   on: push\n   enabled: true\n   ```\n",
  ])
  func everyLineOfAFenceInAQuoteOrListIsIndentedAlike(text: String) {
    #expect(HighlightProbe.role(of: "true", in: text, language: .markdown) == .number)
  }

  @Test func aFenceInAListItemHighlightsPythonAtItsTopLevel() {
    let text = "- a\n\n  ```python\n  x = 1\n  def f():\n      return 1\n  ```\n"
    let spans = HighlightProbe.spans(in: text, language: .markdown)

    #expect(HighlightProbe.role(of: "def", in: text, spans: spans) == .keyword)
    #expect(HighlightProbe.role(of: "return", in: text, spans: spans) == .keyword)
  }

  @Test func anUnquotedFenceWithABlankLineBlanksNothing() throws {
    let found = try InjectionProbe.injections(in: "```py\n\nx = 1\n```\n", language: .markdown)

    #expect(found.map(\.blankedRanges) == [[]])
  }

  @Test func aQuotedFencesMarkersKeepTheQuotesColour() {
    let text = "> ```python\n> def f():\n>     return 1\n> ```\n"
    let spans = HighlightProbe.spans(in: text, language: .markdown)
    let markers = [">     return", "> def"].map { (text as NSString).range(of: $0).location }
    let roles = markers.map { marker in spans.last { $0.range.contains(marker) }?.role }

    #expect(roles == [.punctuation, .punctuation])
  }

  @Test func aSvelteFenceIsGivenItsGrammarAsASvelteFileIs() {
    let prose = String(repeating: "and many more words follow on this line, ", count: 8)
    let text = """
      ```svelte
      <div>
        <p>
          Start a <a
            href="https://example.com"
            target="_blank">token</a
          >. Under "P > A", set the
          \(prose)
        </p>
      </div>
      <section></section>

      <style>
        p { margin: 0; }
      </style>
      ```

      """
    let spans = HighlightProbe.spans(in: text, language: .markdown)

    #expect(HighlightProbe.role(of: "section", in: text, spans: spans) == .keyword)
    #expect(HighlightProbe.role(of: "margin", in: text, spans: spans) == .attribute)
  }

  @Test func aPHPFenceWithoutAnOpeningTagIsReadAsPHP() {
    let text = "```php\n$a = 1;\necho $a;\n```\n"

    #expect(HighlightProbe.role(of: "echo", in: text, language: .markdown) == .keyword)
  }

  @Test func aPHPFenceWithItsOwnOpeningTagIsGivenNoSecond() throws {
    let text = "```php\n<?php echo 1;\n```\n"
    let found = try InjectionProbe.injections(in: text, language: .markdown)

    #expect(found.map(\.prefix) == [""])
    #expect(HighlightProbe.role(of: "echo", in: text, language: .markdown) == .keyword)
  }

  @Test func aFenceRunFollowedByTextOnTheLastLineStaysCode() throws {
    let text = "```sh\necho hi\n```>"
    let found = try InjectionProbe.injections(in: text, language: .markdown)
    let afterInfo = (text as NSString).range(of: "echo").location

    #expect(found.map(\.range) == [afterInfo..<(text as NSString).length])
  }

  @Test func aClosingFenceAtTheEndOfTheFileIsNotReadAsCode() throws {
    let text = "```swift\nlet a = 1\n```"
    let found = try InjectionProbe.injections(in: text, language: .markdown)

    #expect(found.map(\.range) == [(text as NSString).range(of: "let a = 1\n").integerRange])
  }

  @Test func aQuotedClosingFenceAtTheEndOfTheFileIsNotReadAsCode() throws {
    let text = "> ```swift\n> let a = 1\n> ```"
    let found = try InjectionProbe.injections(in: text, language: .markdown)

    #expect(found.map(\.range) == [(text as NSString).range(of: "> let a = 1\n> ").integerRange])
  }

  @Test func aShorterRunAtTheEndOfAnUnclosedFenceStaysCode() throws {
    let text = "````sh\necho\n```"
    let found = try InjectionProbe.injections(in: text, language: .markdown)

    #expect(found.map(\.range) == [(text as NSString).range(of: "echo\n```").integerRange])
  }

  @Test func onlyTheFencesReachingAKeptRangeAreFound() throws {
    let text = "```js\nvar a\n```\n\n```js\nlet b\n```"

    let found = try InjectionProbe.injections(
      in: text,
      language: .markdown,
      within: [InjectionProbe.range(ofLine: 5, in: text)],
    )

    #expect(found.map(\.range) == [(text as NSString).range(of: "let b\n").integerRange])
  }
}
