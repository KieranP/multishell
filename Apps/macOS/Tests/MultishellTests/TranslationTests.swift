import Foundation
import MultishellCore
import Testing

@testable import Multishell

/// The Mac app's own catalogue against the Mac app's own source, the way
/// `Tests/MultishellCoreTests` checks the libraries against theirs.
///
/// Two catalogues and two `t(_:_:)`s, so each is checked where it lives:
/// this package cannot see the libraries' tests, and a frontend added later
/// would carry a third of these. The duplication is the price of the split,
/// and it is what lets a frontend word its chrome without touching what the
/// model says.
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

  /// The app's `t(_:_:)` has to be the one a file of this target gets, and
  /// it has to reach the app's catalogue: a shadowing that stopped working
  /// would send every view to the libraries' words, where most of these
  /// keys are not, and every label would come out as its own key.
  /// Named `Multishell.t` here and not in the app itself: a module that
  /// imports both this one and MultishellCore sees two, and only a file
  /// inside the app gets its own without asking. That is the whole
  /// mechanism, so it is worth one test that says so out loud.
  @Test func theAppsOwnFunctionAnswersFromTheAppsOwnCatalogue() {
    #expect(Multishell.t("menu.new-tab") == "New Tab")
    #expect(
      Multishell.t("count.terminals", 3) == "3 terminals",
      "the app has its own copy of this one")
    #expect(
      Multishell.t("worktree-removal.remove") == "worktree-removal.remove",
      "that word is the libraries', so the app's catalogue answers with the key")
    #expect(
      MultishellCore.t("worktree-removal.remove") == "Remove Worktree",
      "and the libraries' own lookup still finds it")
  }

  /// A word both halves say is written in both catalogues, which is what
  /// keeps a view off the libraries' words. Nothing stops the two copies
  /// parting, and if they do the sidebar and the screen reader describing
  /// it say different things. Checked from this side because the app
  /// already depends on MultishellCore; the libraries do not know a
  /// frontend exists and their own test does not look.
  @Test func aWordInBothCataloguesReadsTheSameInBoth() throws {
    let mine = try Self.catalogue()
    let libraries = try #require(
      NSDictionary(
        contentsOf: Self.checkout.appendingPathComponent(
          "Sources/MultishellCore/Resources/en.lproj/Localizable.strings")) as? [String: String])
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
      let one = Multishell.t(key, 1)
      let many = Multishell.t(key, 2)
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
        "Apps/macOS/Sources/Multishell/Resources/en.lproj/\(name)")
      #expect(
        try Data(contentsOf: built) == (try Data(contentsOf: source)),
        "the built \(name) is not the one on disk; build before running the tests")
    }
  }

  // MARK: - Reading the source and the catalogue

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

  /// …/Apps/macOS/Tests/MultishellTests/<this file>
  private static let checkout = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // MultishellTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()  // macOS
    .deletingLastPathComponent()  // Apps
    .deletingLastPathComponent()

  private static func swiftFiles() throws -> [URL] {
    let start = checkout.appendingPathComponent("Apps/macOS/Sources")
    let walk = FileManager.default.enumerator(at: start, includingPropertiesForKeys: nil)
    return (walk?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
  }
}
