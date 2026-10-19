import Foundation
import MultishellAppCore

/// The language of a `<script>` or `<style>` body, read from the element's
/// attributes, keyed by name. `nil` where no grammar here fits.
enum ElementBodyLanguage {
  private static let scriptByLang: [String: HighlightLanguage] = [
    "js": .javaScript, "javascript": .javaScript, "ts": .typeScript, "typescript": .typeScript,
  ]

  /// HTML's JavaScript MIME type essences, with Babel's and JSX's, whose code the
  /// JavaScript query here colours.
  private static let javaScriptTypes: Set<String> = [
    "module", "application/ecmascript", "application/javascript", "application/x-ecmascript",
    "application/x-javascript", "text/babel", "text/ecmascript", "text/javascript",
    "text/javascript1.0", "text/javascript1.1", "text/javascript1.2", "text/javascript1.3",
    "text/javascript1.4", "text/javascript1.5", "text/jscript", "text/jsx", "text/livescript",
    "text/x-ecmascript", "text/x-javascript",
  ]

  /// A type in neither list is a template or data no grammar here reads.
  private static let jsonTypes: Set<String> = [
    "application/json", "application/ld+json", "importmap", "speculationrules",
  ]

  /// Less and indented Sass have no grammar here, so they stay plain.
  private static let styleByLang: [String: HighlightLanguage] = [
    "css": .css, "postcss": .css, "scss": .scss,
  ]

  static func script(attributes: [String: String], host: MarkupHost) -> HighlightLanguage? {
    switch host {
    case .html: htmlScript(attributes)
    case .svelte: svelteScript(attributes)
    }
  }

  static func style(attributes: [String: String], host: MarkupHost) -> HighlightLanguage? {
    switch host {
    case .html: htmlStyle(attributes)
    case .svelte: svelteStyle(attributes)
    }
  }

  /// Strict, as a browser reads it: a type rid of ASCII whitespace but whole, a
  /// `language` read as `text/` and it, and `lang` a natural language.
  private static func htmlScript(_ attributes: [String: String]) -> HighlightLanguage? {
    let type: String
    if let given = attributes["type"] {
      guard !given.isEmpty else { return .javaScript }
      type = trimmedAndLowercased(given)
    } else {
      guard let language = attributes["language"], !language.isEmpty else { return .javaScript }
      type = ("text/" + language).lowercased()
    }
    return knownScript(type, essence: essence(of: type))
  }

  /// A style's type compared whole, spaces and all, as browsers compare it.
  private static func htmlStyle(_ attributes: [String: String]) -> HighlightLanguage? {
    isCSS(type: attributes["type"]?.lowercased() ?? "") ? .css : nil
  }

  /// Lenient, as Svelte's compiler reads it: `lang` first, then the type, whose
  /// `text/…` stands for a `lang`, then its essence; `language` is not read.
  private static func svelteScript(_ attributes: [String: String]) -> HighlightLanguage? {
    if let lang = svelteLang(in: attributes) { return scriptByLang[lang] }
    let given = attributes["type"] ?? ""
    let type = essence(of: given)
    guard !type.isEmpty else { return .javaScript }
    if let lang = preprocessor(namedBy: given), let language = scriptByLang[lang] {
      return language
    }
    return knownScript(type, essence: type)
  }

  private static func svelteStyle(_ attributes: [String: String]) -> HighlightLanguage? {
    if let lang = svelteLang(in: attributes) { return styleByLang[lang] }
    let given = attributes["type"] ?? ""
    if let lang = preprocessor(namedBy: given), let language = styleByLang[lang] {
      return language
    }
    return isCSS(type: essence(of: given)) ? .css : nil
  }

  private static func isCSS(type: String) -> Bool { ["", "text/css"].contains(type) }

  /// JavaScript or JSON by type; `nil` for a template or data no grammar here reads.
  private static func knownScript(_ type: String, essence: String) -> HighlightLanguage? {
    if javaScriptTypes.contains(type) { return .javaScript }
    // A data block never runs, so its type's parameters cost it nothing.
    return jsonTypes.contains(essence) ? .json : nil
  }

  /// In the case written: Svelte's compiler and its preprocessors compare it exactly.
  private static func svelteLang(in attributes: [String: String]) -> String? {
    guard let lang = attributes["lang"], !lang.isEmpty else { return nil }
    return lang
  }

  /// svelte-preprocess 4 reads `text/scss` or `application/scss` as `lang="scss"`, in the
  /// case written; a name it does not know is read as HTML reads it, `text/babel` too.
  private static func preprocessor(namedBy type: String) -> String? {
    ["text/", "application/"].first(where: type.hasPrefix).map { String(type.dropFirst($0.count)) }
  }

  /// A type rid of its parameters and spaces, in any case: Svelte's reading of
  /// every type, and HTML's of a JSON data block's.
  private static func essence(of type: String) -> String {
    trimmedAndLowercased(type.split(separator: ";", omittingEmptySubsequences: false).first ?? "")
  }

  /// Rid of ASCII whitespace alone, as HTML trims, and in any case.
  private static func trimmedAndLowercased(_ text: some StringProtocol) -> String {
    text.trimmingCharacters(in: ASCIIUnits.whitespaceCharacterSet).lowercased()
  }
}
