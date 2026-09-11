import Foundation
import Testing

@testable import MultishellCore

/// The catalogue and the code that asks it for words have to hold each
/// other up: a key nothing has an entry for reaches a screen as itself, and
/// an entry nothing asks for is a line a translator pays for and nobody
/// reads. A key is a literal at its call site, so both are read off the
/// source, which this finds from its own `#filePath`.
struct TranslationTests {
  @Test func everyKeyTheCodeAsksForIsInTheCatalogue() throws {
    let catalogue = try Self.catalogue()
    for site in try Self.callSites() {
      let isKnown = catalogue[site.key] != nil || Self.countedForms.contains(site.key)
      #expect(isKnown, "\(site.where) asks for \(site.key), which is in neither catalogue file")
    }
  }

  @Test func theCatalogueHasNoEntryNothingAsksFor() throws {
    let asked = Set(try Self.callSites().map(\.key))
    for key in try Self.catalogue().keys.sorted() + Self.countedForms.sorted() {
      // Not `asked.contains(key)` in the expectation itself: a failure
      // prints what it expanded, and that would be every key in the app.
      let isAsked = asked.contains(key)
      #expect(isAsked, "\(key) is in the catalogue and nothing asks for it")
    }
  }

  /// What the enum of keys used to catch at compile time: a call passing
  /// too few arguments prints a raw `%@`, and one passing too many drops
  /// the extra without a word.
  @Test func everyCallPassesTheArgumentsItsPhraseTakes() throws {
    let catalogue = try Self.catalogue()
    for site in try Self.callSites() {
      guard let english = catalogue[site.key] else { continue }
      let takes = Self.placeholders(in: english).count
      #expect(
        site.arguments == takes,
        "\(site.where) passes \(site.arguments) to \(site.key), which takes \(takes)")
    }
    for site in try Self.callSites() where Self.countedForms.contains(site.key) {
      #expect(site.arguments == 1, "\(site.where) counts with \(site.arguments) arguments")
    }
  }

  /// A phrase filled in with two or more arguments has to number them, or a
  /// translation that reorders the sentence silently swaps them. All of
  /// them or none: a phrase that numbers some is counted wrong by
  /// `placeholders(in:)`, and the check above would pass it.
  @Test func everyPhraseWithSeveralArgumentsNumbersThem() throws {
    for (key, english) in try Self.catalogue() {
      let all = english.matches(of: /%[0-9]*\$?[0-9.]*[@dfs]/).map { String($0.output) }
      let numbered = all.filter { $0.contains("$") }
      #expect(
        numbered.isEmpty || numbered.count == all.count,
        "\(key) numbers \(numbered.count) of its \(all.count) placeholders; number all or none")
      guard all.count > 1 else { continue }
      #expect(
        numbered.count == all.count,
        "\(key) takes \(all.count) arguments, so each needs its position: %1$@, %2$@")
    }
  }

  @Test func aCountedPhraseReadsAsSingularAndPlural() {
    #expect(t("count.worktrees", 1) == "1 worktree")
    #expect(t("count.worktrees", 4) == "4 worktrees")
    #expect(t("quit.terminals-open", 1) == "One terminal is still open and will be closed.")
    #expect(t("quit.terminals-open", 2).hasPrefix("2 terminals"))
  }

  /// The keys are read off the source and the words out of the built
  /// bundle, so a run that skipped the build compares one against a copy of
  /// the other made before the edit, and passes on what is no longer there.
  /// `make test` builds first; a bare `swift test --skip-build` need not.
  /// Two ways an entry goes wrong that every other check here passes: a
  /// blank value, which shows nothing where a word should be, and a key
  /// written twice, where the file still parses and `NSDictionary` keeps
  /// one of the two without a word about the other. The second reads the
  /// file rather than the parsed form, which is the only place the loss is
  /// still visible; one entry per line is the convention it counts on.
  @Test func noEntryIsBlankOrWrittenTwice() throws {
    for (key, english) in try Self.catalogue() {
      let isSaid = !english.trimmingCharacters(in: .whitespaces).isEmpty
      #expect(isSaid, "\(key) has an entry with nothing in it")
    }
    let file = try #require(
      Bundle.catalogue.url(forResource: "Localizable", withExtension: "strings"))
    let written = try String(contentsOf: file, encoding: .utf8)
      .matches(of: /^"([^"]+)" =/.anchorsMatchLineEndings())
      .map { String($0.output.1) }
    var seen: Set<String> = []
    for key in written where !seen.insert(key).inserted {
      Issue.record("\(key) is written twice; one of the two is lost on load")
    }
    #expect(written.count == (try Self.catalogue().count))
  }

  /// `%s` is a C string. A Swift `String` handed to one is a pointer where
  /// a pointer is not, which is a crash or worse rather than a wrong word,
  /// and nothing else here would catch it: the argument count is right.
  @Test func noPhraseAsksForACString() throws {
    for (key, english) in try Self.catalogue() {
      let takesACString = english.contains(/%[0-9$]*s/)
      #expect(!takesACString, "\(key) has a %s in it; `%@` is the one that takes a string")
    }
  }

  /// Every counted form, rendered. The rule lives in a plist whose format
  /// key has to name its own sub-dictionary, and a pair that does not match
  /// answers with the raw format rather than a word. Two of these are
  /// exercised by what they say; the rest were only ever checked by being
  /// present.
  @Test func everyCountedFormRendersForOneAndMany() {
    for key in Self.countedForms.sorted() {
      let one = t(key, 1)
      let many = t(key, 2)
      #expect(one != key, "\(key) does not resolve at all")
      #expect(!one.contains("%"), "\(key) at one leaves \(one)")
      #expect(!many.contains("%"), "\(key) at many leaves \(many)")
      #expect(many.contains("2"), "\(key) at many does not say the number: \(many)")
    }
  }

  @Test func theBuiltCatalogueIsNotStale() throws {
    for name in ["Localizable.strings", "Localizable.stringsdict"] {
      let built = try #require(Bundle.catalogue.url(forResource: name, withExtension: nil))
      let source = Self.checkout
        .appendingPathComponent("Sources/MultishellCore/Resources/en.lproj/\(name)")
      #expect(
        try Data(contentsOf: built) == (try Data(contentsOf: source)),
        "the built \(name) is not the one on disk; build before running the tests")
    }
  }

  @Test func aKeyWithNoEntryAnswersWithItself() {
    #expect(t("no.such.key") == "no.such.key")
  }

  // MARK: - Reading the source and the catalogue

  private struct CallSite {
    let key: String
    let arguments: Int
    let `where`: String
  }

  /// Every `t("…")` in the app, with how many arguments it passes. Counted
  /// by walking the brackets rather than by pattern, since an argument is
  /// as often a call as a name.
  private static func callSites() throws -> [CallSite] {
    var sites: [CallSite] = []
    for file in try swiftFiles() {
      let text = try String(contentsOf: file, encoding: .utf8)
      for match in text.matches(of: /\bt\(\s*"([^"]+)"/) {
        sites.append(
          CallSite(
            key: String(match.output.1),
            arguments: arguments(in: text, from: match.range.upperBound),
            where: file.lastPathComponent))
      }
    }
    #expect(sites.count > 100, "the source scan found almost nothing; is the path still right?")
    return sites
  }

  /// Commas at the call's own bracket depth, after the key. Text in a
  /// string literal is skipped, a comma inside one being no argument.
  private static func arguments(in text: String, from start: String.Index) -> Int {
    var depth = 1
    var count = 0
    var index = start
    while index < text.endIndex, depth > 0 {
      switch text[index] {
      case "(", "[", "{": depth += 1
      case ")", "]", "}": depth -= 1
      case "," where depth == 1: count += 1
      case "\"":
        index = text.index(after: index)
        while index < text.endIndex, text[index] != "\"" {
          if text[index] == "\\" { index = text.index(after: index) }
          index = text.index(after: index)
        }
      default: break
      }
      index = text.index(after: index)
    }
    return count
  }

  private static func placeholders(in english: String) -> [String] {
    let all = english.matches(of: /%[0-9]*\$?[0-9.]*[@dfs]/).map { String($0.output) }
    let numbered = Set(all.filter { $0.contains("$") }.map { $0.prefix { $0 != "$" } })
    return numbered.isEmpty ? all : Array(repeating: "%1$@", count: numbered.count)
  }

  private static func catalogue() throws -> [String: String] {
    let file = try #require(
      Bundle.catalogue.url(forResource: "Localizable", withExtension: "strings"))
    return try #require(NSDictionary(contentsOf: file) as? [String: String])
  }

  private static let countedForms: Set<String> = {
    guard let file = Bundle.catalogue.url(forResource: "Localizable", withExtension: "stringsdict"),
      let entries = NSDictionary(contentsOf: file) as? [String: Any]
    else { return [] }
    return Set(entries.keys)
  }()

  /// The checkout this test was compiled from, which is where the source
  /// it reads is.
  private static let checkout = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // MultishellCoreTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()

  private static func swiftFiles() throws -> [URL] {
    let start = checkout.appendingPathComponent("Sources")
    let walk = FileManager.default.enumerator(at: start, includingPropertiesForKeys: nil)
    return (walk?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
  }
}
