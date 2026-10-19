import MultishellAppCore
import Testing

@testable import MultishellHighlight

@Suite
struct HighlightInjectionsElementAttributesTests {
  @Test func aSvelteScriptsLangIsReadInTheCaseItIsWritten() {
    let text = "<script LANG=\"ts\">interface A {}</script>"

    #expect(HighlightProbe.role(of: "interface", in: text, language: .svelte) != .keyword)
  }

  @Test func anHTMLScriptsTypeIsReadInAnyCase() {
    let text = "<script TYPE=\"text/x-template\">const a = 1;</script>"

    #expect(HighlightProbe.role(of: "const", in: text, language: .html) ?? .plain == .plain)
  }

  @Test(arguments: ["lang = \"ts\"", "lang =\"ts\"", "lang= \"ts\""])
  func aSvelteScriptsLangWithSpaceAroundItsEqualsSignIsNoLang(attribute: String) {
    let text = "<script \(attribute)>let a: number</script>"

    #expect(HighlightProbe.role(of: "number", in: text, language: .svelte) != .type)
  }

  @Test func anHTMLScriptsTypeWithSpaceAroundItsEqualsSignIsRead() {
    let text = "<script type = \"text/x-template\">let a = 1</script>"

    #expect(HighlightProbe.role(of: "let", in: text, language: .html) != .keyword)
  }

  @Test func aSvelteScriptsLangIsReadUndecodedAsItsPreprocessorReadsIt() {
    let text = "<script lang=\"t&#115;\">interface A {}</script>"

    #expect(HighlightProbe.role(of: "interface", in: text, language: .svelte) != .keyword)
  }

  @Test func aScriptsTypeIsReadWithItsCharacterReferencesDecoded() {
    let text = "<script type=\"text&#47;javascript\">const a = 1</script>"

    #expect(HighlightProbe.role(of: "const", in: text, language: .html) == .keyword)
  }

  @Test func anHTMLScriptsLangIsItsNaturalLanguageNotItsCode() {
    let text = "<script lang=\"en\">const a = 1;</script>"

    #expect(HighlightProbe.role(of: "const", in: text, language: .html) == .keyword)
  }

  @Test func aRepeatedAttributeIsReadAsItsFirst() {
    let text = "<script type=\"module\" type=\"text/x-template\">const a = 1;</script>"

    #expect(HighlightProbe.role(of: "const", in: text, language: .html) == .keyword)
  }
}
