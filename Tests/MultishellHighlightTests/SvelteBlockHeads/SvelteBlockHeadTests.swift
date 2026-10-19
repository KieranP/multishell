import Testing

@testable import MultishellHighlight

@Suite
struct SvelteBlockHeadTests {
  private static func text(_ range: Range<Int>?, of head: String) -> String? {
    range.map { String(decoding: Array(head.utf16)[$0], as: UTF16.self) }
  }

  @Test(arguments: [
    ("item, i (item.id)", "item, i ", "(item.id)"),
    ("item (f(x))", "item ", "(f(x))"),
    ("item (\")\")", "item ", "(\")\")"),
    ("item (/'/.test(item))", "item ", "(/'/.test(item))"),
    ("item (/\\/\\//.test(item))", "item ", "(/\\/\\//.test(item))"),
    ("{ a = f(() => { return /\\(/ }) } (a)", "{ a = f(() => { return /\\(/ }) } ", "(a)"),
    ("/[ /(/] (a)", "/[ /(/] ", "(a)"),
  ])
  func anEachParameterEndingInParenthesesHasThemAsItsKey(
    head: String,
    pattern: String,
    key: String,
  ) {
    let parts = SvelteBlockHead.eachParameter(head)

    #expect(Self.text(parts.pattern, of: head) == pattern)
    #expect(Self.text(parts.key, of: head) == key)
  }

  @Test(arguments: ["{ id, name }", "[a, b]", "item"])
  func anEachParameterNotEndingInParenthesesHasNoKey(head: String) {
    let parts = SvelteBlockHead.eachParameter(head)

    #expect(parts.key == nil)
    #expect(parts.pattern == 0..<head.utf16.count)
  }

  @Test(arguments: ["(x)", "  (x) "])
  func parenthesesWithNoPatternBeforeThemAreThePatternNotAKey(head: String) {
    let parts = SvelteBlockHead.eachParameter(head)

    #expect(parts.key == nil)
    #expect(parts.pattern == 0..<head.utf16.count)
  }

  @Test(arguments: [
    ("load() then value", "load() ", "then", " value"),
    ("p catch e", "p ", "catch", " e"),
    ("fetch('a then b') then r", "fetch('a then b') ", "then", " r"),
    ("rows[0]\n  then { id }", "rows[0]\n  ", "then", " { id }"),
    ("p! then v", "p! ", "then", " v"),
    ("i++ then v", "i++ ", "then", " v"),
    ("fetch(/'/.source) then r", "fetch(/'/.source) ", "then", " r"),
    ("p /* don't */ then v", "p /* don't */ ", "then", " v"),
    ("p // done\n then v", "p // done\n ", "then", " v"),
    ("load(/\\/\\//) then v", "load(/\\/\\//) ", "then", " v"),
    ("a / b then v", "a / b ", "then", " v"),
    ("f(/\r) / 2 then v", "f(/\r) / 2 ", "then", " v"),
    ("f(/\u{2028}) / 2 then v", "f(/\u{2028}) / 2 ", "then", " v"),
    ("of then v", "of ", "then", " v"),
    ("a + of then v", "a + of ", "then", " v"),
    ("sum(a!/2) + b/2 then v", "sum(a!/2) + b/2 ", "then", " v"),
    ("f(i++ / 2) + x / 3 then v", "f(i++ / 2) + x / 3 ", "then", " v"),
    ("f({a: 1}/2) + g(1)/3 then v", "f({a: 1}/2) + g(1)/3 ", "then", " v"),
    ("typeof /\\/\\//.source then v", "typeof /\\/\\//.source ", "then", " v"),
    ("void /\\/\\// then v", "void /\\/\\// ", "then", " v"),
    ("x / 2 // half\n then v", "x / 2 // half\n ", "then", " v"),
    ("api.new then v", "api.new ", "then", " v"),
    ("load() as Promise<Data> then data", "load() as Promise<Data> ", "then", " data"),
    ("p satisfies Promise<Map<K, V>>\nthen v", "p satisfies Promise<Map<K, V>>\n", "then", " v"),
    ("p as Promise<X[]> then v", "p as Promise<X[]> ", "then", " v"),
    ("p as Promise<{ a: 1 }> then v", "p as Promise<{ a: 1 }> ", "then", " v"),
    ("p as Promise<'a'> then v", "p as Promise<'a'> ", "then", " v"),
    ("f()then v", "f()", "then", " v"),
    ("'p'catch e", "'p'", "catch", " e"),
    ("f(() => { return /\\(/ }) then v", "f(() => { return /\\(/ }) ", "then", " v"),
    ("f(() => { throw /\\(/ }) then v", "f(() => { throw /\\(/ }) ", "then", " v"),
    ("f(x => { if (a) /\\(/.test(a) }) then v", "f(x => { if (a) /\\(/.test(a) }) ", "then", " v"),
    ("f(x => { while (a) /\\(/ }) then v", "f(x => { while (a) /\\(/ }) ", "then", " v"),
    ("f(x => { do /\\(/.test(a) }) then v", "f(x => { do /\\(/.test(a) }) ", "then", " v"),
    ("api.if(x) / 2 then v", "api.if(x) / 2 ", "then", " v"),
    ("api.return / 2 then v", "api.return / 2 ", "then", " v"),
  ])
  func anAwaitHeadSplitsAtItsTopLevelThenOrCatch(
    head: String,
    promise: String,
    keyword: String,
    pattern: String,
  ) {
    let parts = SvelteBlockHead.awaitHead(head)

    #expect(Self.text(parts.promise, of: head) == promise)
    #expect(Self.text(parts.keyword, of: head) == keyword)
    #expect(Self.text(parts.pattern, of: head) == pattern)
  }

  @Test func anAwaitHeadEndingInItsKeywordHasNoPattern() {
    let parts = SvelteBlockHead.awaitHead("p then")

    #expect(Self.text(parts.keyword, of: "p then") == "then")
    #expect(parts.pattern == nil)
  }

  @Test(arguments: [
    "p.then(x)", "load()", "(then)", "athen b", "ready ? then : other", "a || then", "f, then",
    "typeof then", "void then", "await then", "new then", "x instanceof then",
    "load() then{ id }", "a > then", "f => then",
  ])
  func anAwaitHeadWithNoTopLevelKeywordIsAllPromise(head: String) {
    let parts = SvelteBlockHead.awaitHead(head)

    #expect(parts.promise == 0..<head.utf16.count)
    #expect(parts.keyword == nil)
  }
}
