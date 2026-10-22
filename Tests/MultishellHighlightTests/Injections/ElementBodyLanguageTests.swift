import MultishellAppCore
import Testing

@testable import MultishellHighlight

@Suite
struct ElementBodyLanguageTests {
  @Test(arguments: [
    ([:], HighlightLanguage.javaScript),
    (["lang": "ts"], .typeScript),
    (["lang": "typescript"], .typeScript),
    (["type": "module"], .javaScript),
    (["type": "application/ld+json"], .json),
    (["type": "importmap"], .json),
    (["lang": "ts", "type": "module"], .typeScript),
    (["lang": ""], .javaScript),
    (["lang": "", "type": "application/json"], .json),
  ])
  func aSvelteScriptsLanguageComesFromItsLangThenItsType(
    attributes: [String: String],
    language: HighlightLanguage,
  ) {
    #expect(ElementBodyLanguage.script(attributes: attributes, host: .svelte) == language)
  }

  @Test(arguments: [
    (["lang": "en"], HighlightLanguage.javaScript),
    (["lang": "ts"], .javaScript),
    (["lang": "en", "type": "application/json"], .json),
  ])
  func anHTMLScriptsLangIsANaturalLanguageAndIgnored(
    attributes: [String: String],
    language: HighlightLanguage,
  ) {
    #expect(ElementBodyLanguage.script(attributes: attributes, host: .html) == language)
  }

  @Test(arguments: [
    " Module ", "TEXT/JavaScript", "text/babel", "text/jsx", "text/ecmascript",
    "application/ecmascript", "application/x-javascript", "text/x-javascript", "text/jscript",
    "text/livescript", "text/x-ecmascript", "application/x-ecmascript", "text/javascript1.0",
    "text/javascript1.5",
  ])
  func aScriptTypeIsReadTrimmedInAnyCaseForEveryJavaScriptName(type: String) {
    #expect(ElementBodyLanguage.script(attributes: ["type": type], host: .html) == .javaScript)
  }

  @Test func aJSONDataBlocksTypeIsReadWithoutItsParameters() {
    let ldJSON = ["type": "application/ld+json; charset=utf-8"]

    #expect(ElementBodyLanguage.script(attributes: ldJSON, host: .html) == .json)
  }

  @Test func aTypeWithParametersIsDataAsABrowserReadsIt() {
    let script = ["type": "text/javascript; charset=utf-8"]
    let style = ["type": "text/css; charset=utf-8"]

    #expect(ElementBodyLanguage.script(attributes: script, host: .html) == nil)
    #expect(ElementBodyLanguage.style(attributes: style, host: .html) == nil)
  }

  @Test(arguments: [
    (["language": "vbscript"], nil),
    (["language": "JavaScript1.2"], HighlightLanguage.javaScript),
    (["language": "javascript"], .javaScript),
    (["language": "vbscript", "type": "module"], .javaScript),
  ])
  func anHTMLScriptWithNoTypeIsReadByItsLegacyLanguage(
    attributes: [String: String],
    language: HighlightLanguage?,
  ) {
    #expect(ElementBodyLanguage.script(attributes: attributes, host: .html) == language)
  }

  @Test(arguments: [["type": "text/x-template"], ["lang": "coffee"]])
  func aScriptInALanguageWithNoGrammarHereHasNone(attributes: [String: String]) {
    #expect(ElementBodyLanguage.script(attributes: attributes, host: .svelte) == nil)
  }

  @Test func aSvelteStyleIsCSSUnlessItNamesAnotherLanguage() {
    #expect(ElementBodyLanguage.style(attributes: [:], host: .svelte) == .css)
    #expect(ElementBodyLanguage.style(attributes: ["lang": "postcss"], host: .svelte) == .css)
    #expect(ElementBodyLanguage.style(attributes: ["type": "text/css"], host: .svelte) == .css)
    #expect(ElementBodyLanguage.style(attributes: ["lang": "scss"], host: .svelte) == .scss)
    #expect(ElementBodyLanguage.style(attributes: ["lang": "less"], host: .svelte) == nil)
    #expect(ElementBodyLanguage.style(attributes: ["lang": "sass"], host: .svelte) == nil)
  }

  @Test func aSvelteTypeNamingAPreprocessorActsAsItsLang() {
    let typeScript = ["type": "text/typescript"]
    let applicationTypeScript = ["type": "application/typescript"]
    #expect(ElementBodyLanguage.script(attributes: typeScript, host: .svelte) == .typeScript)
    #expect(
      ElementBodyLanguage.script(attributes: applicationTypeScript, host: .svelte) == .typeScript
    )
    #expect(ElementBodyLanguage.style(attributes: ["type": "text/scss"], host: .svelte) == .scss)
    #expect(ElementBodyLanguage.style(attributes: ["type": "text/less"], host: .svelte) == nil)
  }

  @Test func aSvelteTypeNamesAPreprocessorOnlyWhenWrittenWhole() {
    let scss = ["type": "text/scss; charset=utf-8"]
    let typeScript = ["type": "text/typescript "]
    #expect(ElementBodyLanguage.style(attributes: scss, host: .svelte) == nil)
    #expect(ElementBodyLanguage.script(attributes: typeScript, host: .svelte) == nil)
  }

  @Test func aSvelteLangOrTypeNamesItsPreprocessorInExactCase() {
    let shouted = ["lang": "TS"]
    let capitalised = ["lang": "TypeScript"]
    #expect(ElementBodyLanguage.script(attributes: shouted, host: .svelte) == nil)
    #expect(ElementBodyLanguage.script(attributes: capitalised, host: .svelte) == nil)
    #expect(ElementBodyLanguage.style(attributes: ["lang": "SCSS"], host: .svelte) == nil)
    #expect(ElementBodyLanguage.style(attributes: ["type": "text/SCSS"], host: .svelte) == nil)
  }

  @Test(arguments: ["text/babel", "text/jsx", "text/ecmascript"])
  func aSvelteScriptTypeNamingNoLangIsReadAsHTMLReadsIt(type: String) {
    #expect(ElementBodyLanguage.script(attributes: ["type": type], host: .svelte) == .javaScript)
  }

  @Test func anHTMLStylesLangIsIgnored() {
    #expect(ElementBodyLanguage.style(attributes: ["lang": "en"], host: .html) == .css)
  }

  @Test func anHTMLStylesTypeIsMatchedInAnyCase() {
    #expect(ElementBodyLanguage.style(attributes: ["type": "Text/CSS"], host: .html) == .css)
  }

  @Test func anHTMLScriptWhoseTypeIsOnlySpacesIsData() {
    #expect(ElementBodyLanguage.script(attributes: ["type": " "], host: .html) == nil)
    #expect(ElementBodyLanguage.script(attributes: ["type": ""], host: .html) == .javaScript)
  }

  @Test func anHTMLScriptsLegacyLanguageIsComparedUntrimmed() {
    let spaced = ["language": "javascript "]

    #expect(ElementBodyLanguage.script(attributes: spaced, host: .html) == nil)
  }

  @Test func aSvelteScriptsLanguageAttributeIsIgnored() {
    let typeScript = ["language": "ts"]

    #expect(ElementBodyLanguage.script(attributes: typeScript, host: .svelte) == .javaScript)
  }

  @Test func aSvelteTypeIsReadLeniently() {
    let styles = [["type": "text/css "], ["type": "text/css; charset=utf-8"]]
    let script = ["type": "text/javascript; charset=utf-8"]

    for style in styles {
      #expect(ElementBodyLanguage.style(attributes: style, host: .svelte) == .css)
    }
    #expect(ElementBodyLanguage.script(attributes: script, host: .svelte) == .javaScript)
  }

  @Test func aStylesTypeIsComparedUntrimmedAsABrowserDoes() {
    #expect(ElementBodyLanguage.style(attributes: ["type": " text/css "], host: .html) == nil)
  }

  @Test func aScriptsTypeLosesOnlyASCIIWhitespace() {
    let spaced = ["type": "\ttext/javascript\n"]
    let nonBreaking = ["type": "\u{A0}text/javascript"]

    #expect(ElementBodyLanguage.script(attributes: spaced, host: .html) == .javaScript)
    #expect(ElementBodyLanguage.script(attributes: nonBreaking, host: .html) == nil)
  }
}
