import Foundation
import Testing

@testable import MultishellCore

/// A missing key reaches a screen as itself and an unused entry costs a translator. Keys
/// are literals, so both are read off the source, found from `#filePath`.
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

  /// Too few arguments print a raw `%@` and too many are dropped silently; the enum of keys
  /// used to catch both at compile time.
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

  /// Unnumbered, a translation that reorders the sentence swaps the arguments. A phrase
  /// numbering only some is miscounted by `placeholders(in:)`, so the check above passes it.
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

  /// `NSDictionary` silently keeps one of a key written twice, so the duplicate check reads
  /// the raw file and counts on the convention of one entry per line.
  @Test func noEntryIsBlankOrWrittenTwice() throws {
    for (key, english) in try Self.catalogue() {
      let isSaid = !english.trimmingCharacters(in: .whitespaces).isEmpty
      #expect(isSaid, "\(key) has an entry with nothing in it")
    }
    let file = try #require(
      Bundle.coreResources.url(forResource: "Localizable", withExtension: "strings"))
    let written = try String(contentsOf: file, encoding: .utf8)
      .matches(of: /^"([^"]+)" =/.anchorsMatchLineEndings())
      .map { String($0.output.1) }
    var seen: Set<String> = []
    for key in written where !seen.insert(key).inserted {
      Issue.record("\(key) is written twice; one of the two is lost on load")
    }
    #expect(written.count == (try Self.catalogue().count))
  }

  /// A Swift `String` passed to `%s` is read as a C string pointer, a crash rather than a
  /// wrong word, and the argument count check passes it.
  @Test func noPhraseAsksForACString() throws {
    for (key, english) in try Self.catalogue() {
      let takesACString = english.contains(/%[0-9$]*s/)
      #expect(!takesACString, "\(key) has a %s in it; `%@` is the one that takes a string")
    }
  }

  /// A stringsdict format key must name its own sub-dictionary or it answers with the raw
  /// format; most forms were otherwise only checked by being present.
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

  /// Keys come off the source and words off the built bundle, so a run that skipped the
  /// build compares against a stale copy. `make test` builds first; `--skip-build` does not.
  @Test func theBuiltCatalogueIsNotStale() throws {
    for name in ["Localizable.strings", "Localizable.stringsdict"] {
      let built = try #require(Bundle.coreResources.url(forResource: name, withExtension: nil))
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

  private struct CallSite {
    let key: String
    let arguments: Int
    let `where`: String
  }

  /// Arguments are counted by walking the brackets rather than by pattern, since an argument
  /// is as often a call as a name.
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
      Bundle.coreResources.url(forResource: "Localizable", withExtension: "strings"))
    return try #require(NSDictionary(contentsOf: file) as? [String: String])
  }

  private static let countedForms: Set<String> = {
    guard
      let file = Bundle.coreResources.url(forResource: "Localizable", withExtension: "stringsdict"),
      let entries = NSDictionary(contentsOf: file) as? [String: Any]
    else { return [] }
    return Set(entries.keys)
  }()

  private static let checkout = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // Text
    .deletingLastPathComponent()  // MultishellCoreTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()

  /// Not the app's target, whose `t` answers from a catalogue of its own.
  private static func swiftFiles() throws -> [URL] {
    let start = checkout.appendingPathComponent("Sources")
    let app = start.appendingPathComponent("MultishellAppUI").path + "/"
    let walk = FileManager.default.enumerator(at: start, includingPropertiesForKeys: nil)
    return (walk?.allObjects as? [URL] ?? []).filter {
      $0.pathExtension == "swift" && !$0.path.hasPrefix(app)
    }
  }
}
