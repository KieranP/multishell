import Testing

@testable import MultishellHighlight

@Suite
struct CharacterReferencesTests {
  @Test(arguments: [
    ("alert(&quot;x&quot;)", "alert(\"x\")"),
    ("a &amp;&amp; b &lt;= c", "a && b <= c"),
    ("&QUOT;&#X22;&#034;&#x27;&apos;", "\"\"\"''"),
    ("&amp;quot;", "&quot;"),
    ("&nope; &#; & x", "&nope; &#; & x"),
    ("a &amp&amp b &lt c &quot", "a && b < c \""),
    ("&lt=b &ampx", "&lt=b &ampx"),
    ("&#0;&#xD800;&#x110000;", "\u{FFFD}\u{FFFD}\u{FFFD}"),
    ("&#150;&#128;&#x9F;", "\u{2013}\u{20AC}\u{0178}"),
    ("go&lpar;&rpar;&semi; a&colon;b &lcub;&rcub; &excl;&equals;", "go(); a:b {} !="),
  ])
  func aReferenceDecodesToItsCharacter(source: String, text: String) {
    #expect(CharacterReferences.decoded(source).text == text)
  }

  @Test func aDecodedRangeMapsBackOverWholeReferences() {
    let decoded = CharacterReferences.decoded("alert(&quot;x&quot;)")

    #expect(decoded.sourceRange(of: 6..<9) == 6..<19)
    #expect(decoded.sourceRange(of: 0..<5) == 0..<5)
    #expect(decoded.sourceRange(of: 9..<10) == 19..<20)
  }

  @Test func aCharacterOutsideTheBasicPlaneMapsBothItsUnitsToItsReference() {
    let decoded = CharacterReferences.decoded("a&#x1F600;b")

    #expect(decoded.text == "a😀b")
    #expect(decoded.sourceRange(of: 1..<3) == 1..<10)
  }
}
