import Foundation
import MultishellAppCore
import Synchronization
import Testing

@testable import MultishellHighlight

@Suite
struct SyntaxHighlighterTests {
  private final class CompileAttempts: Sendable {
    let byLanguage = Mutex<[HighlightLanguage: Int]>([:])
  }
  private static let source = """
    // Says hello.
    func greet(name: String) -> String {
      let count = 42
      return "hi \\(name)"
    }
    """

  @Test func swiftKeywordsTypesStringsNumbersAndCommentsTakeTheirRoles() {
    let spans = HighlightProbe.spans(in: Self.source, language: .swift)

    #expect(HighlightProbe.role(of: "func", in: Self.source, spans: spans) == .keyword)
    #expect(HighlightProbe.role(of: "String", in: Self.source, spans: spans) == .type)
    #expect(HighlightProbe.role(of: "42", in: Self.source, spans: spans) == .number)
    #expect(HighlightProbe.role(of: "// Says hello.", in: Self.source, spans: spans) == .comment)
    #expect(HighlightProbe.role(of: "hi", in: Self.source, spans: spans) == .string)
  }

  /// `(simple_identifier) @variable` comes first in the query and the
  /// function's own name pattern later, which must win.
  @Test func aLaterPatternWinsOverAnEarlierOneOnTheSameRange() {
    let spans = HighlightProbe.spans(in: Self.source, language: .swift)

    #expect(HighlightProbe.role(of: "greet", in: Self.source, spans: spans) == .function)
  }

  @Test func aGrammarThatFailsToCompileIsTriedOnceAHighlight() {
    let attempts = CompileAttempts()
    let highlighter = SyntaxHighlighter { language in
      attempts.byLanguage.withLock { $0[language, default: 0] += 1 }
      guard language != .javaScript else { throw MissingGrammar(language: language) }
      return try HighlightGrammars.compile(language)
    }

    _ = HighlightProbe.spans(in: "{a}{b}{c}", language: .svelte, highlighter: highlighter)

    #expect(attempts.byLanguage.withLock { $0[.javaScript] } == 1)
  }

  @Test func aGrammarThatFailedToCompileIsTriedAgainOnTheNextHighlight() {
    let attempts = CompileAttempts()
    let highlighter = SyntaxHighlighter { language in
      let attempt = attempts.byLanguage.withLock { byLanguage in
        byLanguage[language, default: 0] += 1
        return byLanguage[language, default: 0]
      }
      guard attempt > 1 else { throw MissingGrammar(language: language) }
      return try HighlightGrammars.compile(language)
    }

    _ = HighlightProbe.spans(in: Self.source, language: .swift, highlighter: highlighter)
    let spans = HighlightProbe.spans(in: Self.source, language: .swift, highlighter: highlighter)

    #expect(HighlightProbe.role(of: "func", in: Self.source, spans: spans) == .keyword)
  }

  @Test func anInjectionWhoseGrammarFailsKeepsTheHostsColour() {
    let highlighter = SyntaxHighlighter { language in
      guard language != .javaScript else { throw MissingGrammar(language: language) }
      return try HighlightGrammars.compile(language)
    }
    let text = "<p onclick=\"go()\">x</p>"
    let spans = HighlightProbe.spans(in: text, language: .html, highlighter: highlighter)

    #expect(HighlightProbe.role(of: "go", in: text, spans: spans) == .string)
  }

  @Test func anInjectionWhoseParserRefusesItsGrammarKeepsTheHostsColour() {
    let highlighter = SyntaxHighlighter { language in
      let compiled = try HighlightGrammars.compile(language)
      guard language == .javaScript else { return compiled }
      return CompiledGrammar(
        language: RejectedLanguage.language,
        query: compiled.query,
        injectionQuery: compiled.injectionQuery,
        rolesFor: language,
      )
    }
    let text = "<p onclick=\"go()\">x</p>"
    let spans = HighlightProbe.spans(in: text, language: .html, highlighter: highlighter)

    #expect(HighlightProbe.role(of: "go", in: text, spans: spans) == .string)
  }

  @Test func anInjectionReachingNoRangeAskedForIsNotParsed() {
    let text = "<script>var a</script>\n<script>let b</script>"
    let reached = (text as NSString).range(of: "b<").integerRange
    var cache = HighlightPassCache()

    let spans = SyntaxHighlighter.shared.spans(
      in: text,
      language: .html,
      cache: &cache,
      within: [reached],
    )

    #expect(HighlightProbe.role(of: "var", in: text, spans: spans) != .keyword)
    #expect(HighlightProbe.role(of: "let", in: text, spans: spans) == .keyword)
  }

  @Test func anAttributeAboveARangeAskedForInTheSameTagIsNotParsed() {
    let text = "<p onclick=\"go()\"\n  style=\"color: red\">x</p>"
    let reached = (text as NSString).range(of: "  style=\"color: red\">x</p>").integerRange
    var cache = HighlightPassCache()

    let spans = SyntaxHighlighter.shared.spans(
      in: text,
      language: .html,
      cache: &cache,
      within: [reached],
    )

    #expect(HighlightProbe.role(of: "go", in: text, spans: spans) != .function)
    #expect(HighlightProbe.role(of: "color", in: text, spans: spans) == .attribute)
  }

  @Test func aHostCaptureReachingNoRangeAskedForIsNotQueried() {
    let text = "let a = 1\nvar b = 2"
    let reached = (text as NSString).range(of: "var b").integerRange
    var cache = HighlightPassCache()

    let spans = SyntaxHighlighter.shared.spans(
      in: text,
      language: .swift,
      cache: &cache,
      within: [reached],
    )

    #expect(HighlightProbe.role(of: "let", in: text, spans: spans) == nil)
    #expect(HighlightProbe.role(of: "var", in: text, spans: spans) == .keyword)
  }

  @Test func aHostCaptureOpenedAboveARangeAskedForStillColoursIt() {
    let text = "/* a\nb */\nlet c"
    let reached = (text as NSString).range(of: "b */").integerRange
    var cache = HighlightPassCache()

    let spans = SyntaxHighlighter.shared.spans(
      in: text,
      language: .swift,
      cache: &cache,
      within: [reached],
    )

    #expect(HighlightProbe.role(of: "b", in: text, spans: spans) == .comment)
  }

  @Test(arguments: ["Under \"P > A\", set", "Tom & Jerry", "Tom &1 Jerry", "Tom &# Jerry"])
  func aGreaterThanOrBareAmpersandInSvelteTextLeavesTheMarkupAndStyleAfterItHighlighted(
    words: String
  ) {
    let prose = String(repeating: "and many more words follow on this line, ", count: 8)
    let text = """
      <div>
        <p>
          Start a <a
            href="https://example.com"
            target="_blank">token</a
          >. \(words) the
          \(prose)
        </p>
      </div>
      <section></section>

      <style>
        p { margin: 0; }
      </style>
      """
    let spans = HighlightProbe.spans(in: text, language: .svelte)

    #expect(HighlightProbe.role(of: "section", in: text, spans: spans) == .keyword)
    #expect(HighlightProbe.role(of: "margin", in: text, spans: spans) == .attribute)
  }

  @Test func markdownEndingInACRLFIsGivenToItsGrammarUnchanged() {
    #expect(SyntaxHighlighter.grammarInput(from: "a\r\n", language: .markdown) == "a\r\n")
  }

  @Test func aRangeCountsInUTF16SoAnEmojiBeforeItShiftsNothing() {
    let text = "let 🙂 = 1\nfunc f() {}"
    let spans = HighlightProbe.spans(in: text, language: .swift)
    let funcRange = (text as NSString).range(of: "func")

    #expect(
      spans.contains { span in
        span.role == .keyword && span.range == funcRange.integerRange
      }
    )
  }

  /// One word each grammar's query must colour, so a grammar whose query
  /// compiles but captures nothing fails here.
  @Test(arguments: [
    (HighlightLanguage.bash, "if true; then echo hi; fi", "if"),
    (.c, "int main(void) { return 0; }", "return"),
    (.cpp, "class A { public: int b; };", "class"),
    (.cSharp, "public class A { }", "class"),
    (.css, "p { width: 10px; }", "10"),
    (.golang, "package main\nfunc main() {}", "func"),
    (.html, "<div class=\"a\"></div>", "div"),
    (.java, "public class A { }", "class"),
    (.javaScript, "const a = () => <b>{1}</b>;", "const"),
    (.json, "{\"a\": true}", "true"),
    (.kotlin, "fun main() { val a = 1 }", "fun"),
    (.makefile, "all:\n\techo hi\n", "all"),
    (.markdown, "# Title\n\ntext", "Title"),
    (.php, "<?php function f() { return 1; }", "function"),
    (.python, "def f():\n    return 1", "def"),
    (.ruby, "def greet\n  puts 1\nend", "def"),
    (.rust, "fn main() { let x = 1; }", "fn"),
    (.scss, "@mixin m { width: 10px; }", "@mixin"),
    (.sql, "SELECT a FROM b;", "SELECT"),
    (.svelte, "{#each items as item}<li/>{/each}", "each"),
    (.toml, "[a]\nb = true", "true"),
    (.tsx, "const a: number = <b/>;", "const"),
    (.typeScript, "interface A { b: string }", "interface"),
    (.yaml, "a: true", "true"),
    (.zig, "const a = 1;", "const"),
  ])
  func eachGrammarColoursAWordOfItsLanguage(
    language: HighlightLanguage,
    text: String,
    word: String,
  ) {
    let spans = HighlightProbe.spans(in: text, language: language)
    let range = (text as NSString).range(of: word)

    #expect(
      spans.contains { $0.role != .plain && $0.range.contains(range.location) },
      "\(language) left \(word) plain",
    )
  }
}
