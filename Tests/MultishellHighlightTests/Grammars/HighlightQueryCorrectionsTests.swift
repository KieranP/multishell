import MultishellAppCore
import Testing

@testable import MultishellHighlight

@Suite
struct HighlightQueryCorrectionsTests {
  @Test func anSCSSMixinOrFunctionNameIsAFunction() {
    let text = "@mixin big($a) { width: $a; }\n@function twice($n) { @return $n * 2; }"

    #expect(HighlightProbe.role(of: "big", in: text, language: .scss) == .function)
    #expect(HighlightProbe.role(of: "twice", in: text, language: .scss) == .function)
  }

  @Test(arguments: [HighlightLanguage.css, .scss])
  func aCustomPropertyIsAVariableWhereDefinedAndWhereUsed(language: HighlightLanguage) {
    let defined = ":root { --main: red; }"
    let used = "p { color: var(--main); }"

    #expect(HighlightProbe.role(of: "--main", in: defined, language: language) == .plain)
    #expect(HighlightProbe.role(of: "--main", in: used, language: language) == .plain)
  }

  @Test func aSvelteElseIfIsAKeyword() {
    let text = "{#if a}x{:else if b}y{/if}"

    #expect(HighlightProbe.role(of: "else if", in: text, language: .svelte) == .keyword)
  }

  @Test func aCustomPropertyLeavesAnOrdinaryPropertyAnAttribute() {
    let text = ":root { --main: red; color: blue; }"

    #expect(HighlightProbe.role(of: "color", in: text, language: .css) == .attribute)
  }
}
