import Foundation
import MultishellAppCore
import Testing

@testable import MultishellHighlight

@Suite
struct HighlightInjectionsAttributeInjectionsTests {
  @Test(arguments: [HighlightLanguage.html, .svelte])
  func anInlineStyleIsHighlightedAsCSS(language: HighlightLanguage) {
    let text = "<p style=\"width: 10px\">x</p>"

    #expect(HighlightProbe.role(of: "10", in: text, language: language) == .number)
  }

  @Test func anInlineStylesValuesLoseTheAttributesStringColour() {
    let text = "<p style=\"color: red\">x</p>"

    #expect(HighlightProbe.role(of: "red", in: text, language: .html) == .plain)
  }

  @Test func anAttributeStartingWithOnThatIsNoEventHandlerKeepsItsString() {
    let custom = "<my-el one=\"Yes\" oxclick=\"No\"></my-el>"

    #expect(HighlightProbe.role(of: "Yes", in: custom, language: .html) == .string)
    #expect(HighlightProbe.role(of: "No", in: custom, language: .html) == .string)
  }

  @Test func aSvelteComponentsOnPropKeepsItsString() {
    let text = "<Toggle onclick=\"Yes\" onLabel=\"No\" />"

    #expect(HighlightProbe.role(of: "Yes", in: text, language: .svelte) == .string)
    #expect(HighlightProbe.role(of: "No", in: text, language: .svelte) == .string)
  }

  @Test(arguments: [
    "<ui.Button onclick=\"Yes\" />", "<svelte:component this={X} onclick=\"Yes\" />",
    "<svelte:self onclick=\"Yes\" />",
  ])
  func aSvelteComponentWrittenAnyWayKeepsItsOnPropsString(text: String) {
    #expect(HighlightProbe.role(of: "Yes", in: text, language: .svelte) == .string)
  }

  @Test func aSvelteElementTagsHandlerIsHighlighted() {
    let text = "<svelte:element this=\"p\" onclick=\"go()\" />"

    #expect(HighlightProbe.role(of: "go", in: text, language: .svelte) == .function)
  }

  @Test(arguments: ["window", "document", "body"])
  func aSvelteWindowDocumentOrBodysStringHandlerAndStyleKeepTheirStrings(tag: String) {
    let text = "<svelte:\(tag) onkeydown=\"go()\" style=\"top: 1\" />"

    #expect(HighlightProbe.role(of: "go", in: text, language: .svelte) == .string)
    #expect(HighlightProbe.role(of: "1", in: text, language: .svelte) == .string)
  }

  @Test(arguments: ["<svelte:boundary onerror=\"go()\">", "<svelte:fragment style=\"go\">"])
  func aSvelteSpecialElementStandingForNoNodeKeepsItsStrings(text: String) {
    #expect(HighlightProbe.role(of: "go", in: text, language: .svelte) == .string)
  }

  @Test(arguments: ["command", "fullscreenchange", "pointerrawupdate", "scrollsnapchange"])
  func aNewerEventHandlerIsHighlightedAsJavaScript(event: String) {
    let text = "<button on\(event)=\"go()\">x</button>"

    #expect(HighlightProbe.role(of: "go", in: text, language: .html) == .function)
  }

  @Test(arguments: ["search", "mousewheel"])
  func aNonStandardHandlerChromeAndSafariRunIsHighlightedAsJavaScript(event: String) {
    let text = "<input on\(event)=\"go()\">"

    #expect(HighlightProbe.role(of: "go", in: text, language: .html) == .function)
  }

  @Test func anAttributesCharacterReferencesReadAsTheCharactersTheyStandFor() {
    let handler = "<div onclick=\"alert(&quot;x&quot;)\">d</div>"
    let style = "<p style=\"font-family: &#39;A B&#39;\">p</p>"

    #expect(HighlightProbe.role(of: "x&quot;", in: handler, language: .html) == .string)
    #expect(HighlightProbe.role(of: "A B&#39;", in: style, language: .html) == .string)
  }

  @Test func eachStyleAndHandlerAttributeIsInjectedOnce() throws {
    let text = "<div style=\"color: red\" data-x=\"y\" onclick=\"go()\">x</div>"

    #expect(try InjectionProbe.languages(in: text) == [.css, .javaScript])
  }

  @Test func aStyleOrHandlerNameInTextCodeOrAValueIsNoAttribute() throws {
    let text = "<p title=\"style = x\">style = x</p><script>onload = f</script>"

    #expect(try InjectionProbe.languages(in: text) == [.javaScript])
  }

  @Test func aSvelteComponentsStyleIsAStringProp() {
    let text = "<Card style=\"compact\" />"

    #expect(HighlightProbe.role(of: "compact", in: text, language: .svelte) == .string)
  }

  @Test func aSvelteHandlerAfterASpreadIsHighlightedAsJavaScript() {
    let text = "<div {...rest}onclick=\"go()\">x</div>"

    #expect(HighlightProbe.role(of: "go", in: text, language: .svelte) == .function)
  }

  @Test func anHTMLEventHandlerIsHighlightedAsJavaScript() {
    let text = "<button onclick=\"return go()\">x</button>"

    #expect(HighlightProbe.role(of: "return", in: text, language: .html) == .keyword)
  }

  @Test func aSvelteSlotsHandlerAndStyleAreStringProps() {
    let text = "<slot onclick=\"go()\" style=\"color: red\"></slot>"

    #expect(HighlightProbe.role(of: "go", in: text, language: .svelte) == .string)
    #expect(HighlightProbe.role(of: "red", in: text, language: .svelte) == .string)
  }

  @Test(arguments: [HighlightLanguage.html, .svelte])
  func aRepeatedHandlerOrStyleOnOneElementIsInjectedAsItsFirst(language: HighlightLanguage) {
    let text = "<p onclick=\"first()\" onclick=\"second()\" style=\"top: 0\" style=\"top: 1\">"

    #expect(HighlightProbe.role(of: "first", in: text, language: language) == .function)
    #expect(HighlightProbe.role(of: "second", in: text, language: language) == .string)
    #expect(HighlightProbe.role(of: "1", in: text, language: language) == .string)
  }

  @Test(arguments: [HighlightLanguage.html, .svelte])
  func aHandlerOrStyleAfterABareOneOfItsNameKeepsItsString(language: HighlightLanguage) {
    let text = "<p onclick onclick=\"go()\" style style=\"top: 1\">"

    #expect(HighlightProbe.role(of: "go", in: text, language: language) == .string)
    #expect(HighlightProbe.role(of: "1", in: text, language: language) == .string)
  }

  @Test func anHTMLHandlerRepeatedInAnotherCaseKeepsItsString() {
    let text = "<p onclick=\"first()\" ONCLICK=\"second()\">x</p>"

    #expect(HighlightProbe.role(of: "second", in: text, language: .html) == .string)
  }

  @Test(arguments: [HighlightLanguage.html, .svelte])
  func aStyleRepeatedInAnotherCaseKeepsItsString(language: HighlightLanguage) {
    let text = "<p style=\"color: red\" STYLE=\"top: 1\">x</p>"

    #expect(HighlightProbe.role(of: "1", in: text, language: language) == .string)
  }

  @Test func aHandlerEndingInAnUnclosedCommentLeavesItUnfinished() {
    let text = "<button onclick=\"go() /* todo\">x</button>"

    #expect(HighlightProbe.role(of: "todo", in: text, language: .html) != .comment)
  }

  @Test(arguments: [
    "webkitanimationend", "webkitanimationiteration", "webkitanimationstart",
    "webkittransitionend",
  ])
  func aWebKitPrefixedHandlerIsHighlightedAsJavaScript(event: String) {
    let text = "<div on\(event)=\"go()\">x</div>"

    #expect(HighlightProbe.role(of: "go", in: text, language: .html) == .function)
  }

  @Test(arguments: ["begin", "end", "repeat"])
  func anSVGAnimationsHandlerIsHighlightedAsJavaScript(event: String) {
    let text = "<svg><animate on\(event)=\"go()\"/></svg>"

    #expect(HighlightProbe.role(of: "go", in: text, language: .html) == .function)
  }

  @Test func anInlineStyleEndingInAnUnclosedCommentColoursItAsAComment() {
    let text = "<p style=\"color: red /* note\">x</p>"

    #expect(HighlightProbe.role(of: "note", in: text, language: .html) == .comment)
    #expect(HighlightProbe.role(of: "color", in: text, language: .html) == .attribute)
  }

  @Test func anInlineStyleHoldingACommentOpenerInAStringIsNotClosed() {
    let text = "<p style=\"content: '/*'; color: red\">x</p>"

    #expect(HighlightProbe.role(of: "'/*'", in: text, language: .html) == .string)
    #expect(HighlightProbe.role(of: "red", in: text, language: .html) == .plain)
  }

  @Test func aRepeatedHandlerInAKeptRangeStaysARepeatOfOneAboveIt() throws {
    let text = "<p onclick=\"a()\"\n  ONCLICK=\"b()\">x</p>"
    let repeated = (text as NSString).range(of: "b()").integerRange

    let found = try InjectionProbe.injections(
      in: text,
      within: [InjectionProbe.range(ofLine: 1, in: text)],
    )

    #expect(!found.map(\.range).contains(repeated))
  }
}
