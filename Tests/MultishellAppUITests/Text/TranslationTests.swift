import Foundation
import MultishellCore
import Testing

@testable import MultishellAppUI

/// Pairs with the TranslationTests in `Tests/MultishellCoreTests`: a check added to one goes in
/// the other; see Docs/develop/tests.md.
@Suite
struct TranslationTests {
  @Test func everyKeyTheAppAsksForIsInItsOwnCatalogue() throws {
    let catalogue = try Self.catalogue()
    for site in try Self.callSites() {
      let isKnown = catalogue[site.key] != nil || Self.countedForms.contains(site.key)
      #expect(
        isKnown,
        """
        \(site.where) asks for \(site.key), which the app's catalogue has not got. A word the \
        libraries also say is written in both; the app never reads theirs.
        """)
    }
  }

  @Test func theAppCatalogueHasNoEntryNothingAsksFor() throws {
    let asked = Set(try Self.callSites().map(\.key))
    for key in try Self.catalogue().keys.sorted() + Self.countedForms.sorted() {
      let isAsked = asked.contains(key)
      #expect(isAsked, "\(key) is in the app's catalogue and nothing in the app asks for it")
    }
  }

  @Test func everyCallPassesTheArgumentsItsPhraseTakes() throws {
    let catalogue = try Self.catalogue()
    for site in try Self.callSites() {
      if let english = catalogue[site.key] {
        let takes = Self.placeholders(in: english).count
        #expect(
          site.arguments == takes,
          "\(site.where) passes \(site.arguments) to \(site.key), which takes \(takes)")
      } else if Self.countedForms.contains(site.key) {
        #expect(site.arguments == 1, "\(site.where) counts with \(site.arguments) arguments")
      }
    }
  }

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

  /// A shadowing that stopped working would send every view to the libraries' words, each label
  /// coming out as its key. Qualified here because this module imports both halves.
  @Test func theAppsOwnFunctionAnswersFromTheAppsOwnCatalogue() {
    #expect(MultishellAppUI.t("menu.new-tab") == "New Tab")
    #expect(
      MultishellAppUI.t("count.terminals", 3) == "3 terminals",
      "the app has its own copy of this one")
    #expect(
      MultishellAppUI.t("worktree-removal.remove") == "worktree-removal.remove",
      "that word is the libraries', so the app's catalogue answers with the key")
    #expect(
      MultishellCore.t("worktree-removal.remove") == "Remove Worktree",
      "and the libraries' own lookup still finds it")
  }

  @Test func aCountedPhraseReadsAsSingularAndPlural() {
    #expect(MultishellAppUI.t("count.terminals", 1) == "1 terminal")
    #expect(MultishellAppUI.t("count.worktrees", 1) == "1 worktree")
    #expect(MultishellAppUI.t("count.worktrees", 4) == "4 worktrees")
  }

  @Test func aKeyWithNoEntryAnswersWithItself() {
    #expect(MultishellAppUI.t("no.such.key") == "no.such.key")
  }

  /// Checked from this side because the libraries do not know a frontend exists; copies that
  /// part leave the sidebar and the screen reader describing it saying different things.
  @Test func aWordInBothCataloguesReadsTheSameInBoth() throws {
    let mine = try Self.catalogue()
    let libraries = try #require(
      NSDictionary(contentsOf: Self.libraryCatalogue("strings")) as? [String: String])
    let shared = Set(mine.keys).intersection(libraries.keys)
    #expect(!shared.isEmpty, "no key is in both, so this is checking nothing")
    for key in shared.sorted() {
      #expect(
        mine[key] == libraries[key],
        """
        \(key) is in both catalogues and they have parted: the app says \(mine[key] ?? "") \
        and the libraries say \(libraries[key] ?? "")
        """)
    }
  }

  /// The check above compares like file to like, so `status.unscored` being
  /// `~%d` here and a counted form in the libraries went through it unseen.
  @Test func noKeyIsAPhraseInOneHalfAndACountedFormInTheOther() throws {
    let libraryPhrases = try #require(
      NSDictionary(contentsOf: Self.libraryCatalogue("strings")) as? [String: String])
    let libraryCounted = try #require(
      NSDictionary(contentsOf: Self.libraryCatalogue("stringsdict")) as? [String: Any])

    for key in Set(try Self.catalogue().keys).intersection(libraryCounted.keys).sorted() {
      Issue.record("\(key) is a phrase here and a counted form in the libraries")
    }
    for key in Self.countedForms.intersection(libraryPhrases.keys).sorted() {
      Issue.record("\(key) is a counted form here and a phrase in the libraries")
    }
    let file = try #require(
      Bundle.appCatalogue.url(forResource: "Localizable", withExtension: "stringsdict"))
    let ours = try #require(NSDictionary(contentsOf: file) as? [String: Any])
    for key in Self.countedForms.intersection(libraryCounted.keys).sorted() {
      #expect(
        (ours[key] as? NSDictionary) == (libraryCounted[key] as? NSDictionary),
        "\(key) is counted in both catalogues and the two rules have parted")
    }
  }

  @Test func everyInfoTextFitsTwoHundredCharactersFilledIn() throws {
    for (key, english) in try Self.catalogue() where key.hasSuffix("-info") {
      let filled = english.replacing(/%([0-9]+\$)?@/, with: SharedProjectSettings.fileName)
        .replacing(/%([0-9]+\$)?d/, with: "10")
      #expect(filled.count <= 200, "\(key) is \(filled.count) characters")
    }
  }

  /// `NSDictionary` silently keeps one of a key written twice, so the second check reads the file
  /// as text, counting on one entry per line.
  @Test func noEntryIsBlankOrWrittenTwice() throws {
    for (key, english) in try Self.catalogue() {
      let isSaid = !english.trimmingCharacters(in: .whitespaces).isEmpty
      #expect(isSaid, "\(key) has an entry with nothing in it")
    }
    let file = try #require(
      Bundle.appCatalogue.url(forResource: "Localizable", withExtension: "strings"))
    let written = try String(contentsOf: file, encoding: .utf8)
      .matches(of: /^"([^"]+)" =/.anchorsMatchLineEndings())
      .map { String($0.output.1) }
    var seen: Set<String> = []
    for key in written where !seen.insert(key).inserted {
      Issue.record("\(key) is written twice; one of the two is lost on load")
    }
    #expect(written.count == (try Self.catalogue().count))
  }

  /// A Swift `String` handed to `%s` is read as a C pointer, a crash rather than a wrong word, and
  /// the argument count check still passes.
  @Test func noPhraseAsksForACString() throws {
    for (key, english) in try Self.catalogue() {
      let takesACString = english.contains(/%[0-9$]*s/)
      #expect(!takesACString, "\(key) has a %s in it; `%@` is the one that takes a string")
    }
  }

  /// A format key that does not name its own sub-dictionary answers with the raw format, and
  /// most forms are otherwise only checked by being present.
  @Test func everyCountedFormRendersForOneAndMany() {
    for key in Self.countedForms.sorted() {
      let one = MultishellAppUI.t(key, 1)
      let many = MultishellAppUI.t(key, 2)
      #expect(one != key, "\(key) does not resolve at all")
      #expect(!one.contains("%"), "\(key) at one leaves \(one)")
      #expect(!many.contains("%"), "\(key) at many leaves \(many)")
      #expect(many.contains("2"), "\(key) at many does not say the number: \(many)")
    }
  }

  @Test func theBuiltCatalogueIsNotStale() throws {
    for name in ["Localizable.strings", "Localizable.stringsdict"] {
      let built = try #require(Bundle.appCatalogue.url(forResource: name, withExtension: nil))
      let source = Self.checkout.appendingPathComponent(
        "Sources/MultishellAppUI/Resources/en.lproj/\(name)")
      #expect(
        try Data(contentsOf: built) == (try Data(contentsOf: source)),
        "the built \(name) is not the one on disk; build before running the tests")
    }
  }

  /// A literal is looked up in `Bundle.main`, which has no catalogue, and every other check here
  /// starts at a `t` call; see Docs/design/translation.md.
  @Test func noViewLabelsItselfWithALiteral() throws {
    for file in try Self.swiftFiles() {
      let text = try String(contentsOf: file, encoding: .utf8)
      for match in text.matches(of: Self.literalLabel()) {
        Issue.record(
          """
          \(file.lastPathComponent) says \(String(match.output.0)), a word \
          Bundle.main would be asked for; write it as t("a.key")
          """)
      }
    }
  }

  /// Built per call: a `Regex` is not `Sendable`, so a `static let` of one does not compile.
  private static func literalLabel() -> Regex<(Substring, Substring)> {
    /\b(Text|Label|Button|Toggle|Picker|TextField|SecureField|Stepper|Link|Section|GroupBox|DisclosureGroup|help|navigationTitle|accessibilityLabel|accessibilityHint|alert|confirmationDialog)\(\s*"[^"\\(]+"/
  }

  private struct CallSite {
    let key: String
    let arguments: Int
    let `where`: String
  }

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

  private static func libraryCatalogue(_ kind: String) -> URL {
    checkout.appendingPathComponent("Sources/MultishellCore/Resources/en.lproj/Localizable.\(kind)")
  }

  private static func catalogue() throws -> [String: String] {
    let file = try #require(
      Bundle.appCatalogue.url(forResource: "Localizable", withExtension: "strings"))
    return try #require(NSDictionary(contentsOf: file) as? [String: String])
  }

  private static let countedForms: Set<String> = {
    guard
      let file = Bundle.appCatalogue.url(forResource: "Localizable", withExtension: "stringsdict"),
      let entries = NSDictionary(contentsOf: file) as? [String: Any]
    else { return [] }
    return Set(entries.keys)
  }()

  private static let checkout = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // Text
    .deletingLastPathComponent()  // MultishellAppUITests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()

  private static func swiftFiles() throws -> [URL] {
    let start = checkout.appendingPathComponent("Sources/MultishellAppUI")
    let walk = FileManager.default.enumerator(at: start, includingPropertiesForKeys: nil)
    return (walk?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
  }
}
