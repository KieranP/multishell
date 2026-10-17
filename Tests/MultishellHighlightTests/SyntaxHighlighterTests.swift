import Foundation
import MultishellAppCore
import Testing

@testable import MultishellHighlight

@Suite
struct SyntaxHighlighterTests {
  private static let source = """
    // Says hello.
    func greet(name: String) -> String {
      let count = 42
      return "hi \\(name)"
    }
    """

  /// The role last applied over the first occurrence of `text`, as the view
  /// applies spans in turn.
  private static func role(of text: String, in spans: [HighlightSpan]) -> HighlightRole? {
    let range = (source as NSString).range(of: text)
    let covering = spans.filter { span in
      span.range.lowerBound <= range.location && span.range.upperBound >= NSMaxRange(range)
    }
    return covering.last?.role
  }

  @Test func swiftKeywordsTypesStringsNumbersAndCommentsTakeTheirRoles() {
    let spans = SyntaxHighlighter.shared.spans(in: Self.source, language: .swift)

    #expect(Self.role(of: "func", in: spans) == .keyword)
    #expect(Self.role(of: "String", in: spans) == .type)
    #expect(Self.role(of: "42", in: spans) == .number)
    #expect(Self.role(of: "// Says hello.", in: spans) == .comment)
    #expect(Self.role(of: "hi", in: spans) == .string)
  }

  /// `(simple_identifier) @variable` comes first in the query and the
  /// function's own name pattern later, which must win.
  @Test func aLaterPatternWinsOverAnEarlierOneOnTheSameRange() {
    let spans = SyntaxHighlighter.shared.spans(in: Self.source, language: .swift)

    #expect(Self.role(of: "greet", in: spans) == .function)
  }

  @Test func aRangeCountsInUTF16SoAnEmojiBeforeItShiftsNothing() {
    let text = "let 🙂 = 1\nfunc f() {}"
    let spans = SyntaxHighlighter.shared.spans(in: text, language: .swift)
    let funcRange = (text as NSString).range(of: "func")

    #expect(
      spans.contains { span in
        span.role == .keyword && span.range == funcRange.location..<NSMaxRange(funcRange)
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
    (.golang, "package main\nfunc main() {}", "func"),
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
    (.sql, "SELECT a FROM b;", "SELECT"),
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
    let spans = SyntaxHighlighter.shared.spans(in: text, language: language)
    let range = (text as NSString).range(of: word)

    #expect(
      spans.contains { $0.role != .plain && $0.range.contains(range.location) },
      "\(language) left \(word) plain",
    )
  }
}
