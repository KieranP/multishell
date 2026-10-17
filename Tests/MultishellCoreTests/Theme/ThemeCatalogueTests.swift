import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct ThemeCatalogueTests {
  @Test func userFilesAreAddedAndCanReplaceBuiltins() throws {
    let directory = try Scratch.directory("themes")
    defer { Scratch.remove(directory) }

    try Data(#"{ "id": "user.custom", "name": "Custom" }"#.utf8)
      .write(to: directory.appendingPathComponent("custom.json"))
    try Data(#"{ "id": "multishell.light", "name": "Light, but mine", "is_dark": false }"#.utf8)
      .write(to: directory.appendingPathComponent("light.json"))
    try Data("{".utf8).write(to: directory.appendingPathComponent("broken.json"))

    let catalogue = ThemeCatalogue.loadRemovingStrayExamples(from: directory)

    #expect(Set(catalogue.themes.map(\.id)) == Set(Theme.builtins.map(\.id) + ["user.custom"]))
    #expect(catalogue.themes.first { $0.id == Theme.multishellLight.id }?.name == "Light, but mine")
    #expect(catalogue.problems.count == 1)
  }

  @Test func themesAreListedByNameWithAUsersAmongTheBuiltIns() throws {
    let directory = try Scratch.directory("themes")
    defer { Scratch.remove(directory) }
    try Data(#"{ "id": "user.ayu", "name": "Ayu Mirage" }"#.utf8)
      .write(to: directory.appendingPathComponent("ayu.json"))
    try Data(#"{ "id": "user.zen", "name": "zenburn" }"#.utf8)
      .write(to: directory.appendingPathComponent("zen.json"))

    let names = ThemeCatalogue.loadRemovingStrayExamples(from: directory).themes.map(\.name)

    #expect(names.first == "Ayu Mirage")
    #expect(names.last == "zenburn")
    #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
  }

  @Test func theBuiltInsAloneAreListedByName() {
    let names = ThemeCatalogue.builtinsOnly.themes.map(\.name)

    #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
  }

  @Test func aThemeFileWithFewColoursLoadsAndOneThatIsNotAThemeIsAProblem() throws {
    let directory = try Scratch.directory("themes")
    defer { Scratch.remove(directory) }
    try Data(#"{ "id": "user.short", "name": "Short", "ui": { "header": {} } }"#.utf8)
      .write(to: directory.appendingPathComponent("short.json"))
    try Data(#"{ "name": "No id" }"#.utf8).write(to: directory.appendingPathComponent("anon.json"))

    let catalogue = ThemeCatalogue.loadRemovingStrayExamples(from: directory)

    #expect(Set(catalogue.themes.map(\.id)) == Set(Theme.builtins.map(\.id) + ["user.short"]))
    #expect(catalogue.problems.count == 1)
    #expect(catalogue.problems.first?.fileName == "anon.json")
  }

  /// What an earlier build wrote: a flat example, at the top and moved into `examples/`.
  @Test func loadingRemovesExamplesAnEarlierBuildLeftAndLoadsNoneOfThem() throws {
    let directory = try Scratch.directory("themes")
    defer { Scratch.remove(directory) }
    let examples = directory.appendingPathComponent("examples")
    try FileManager.default.createDirectory(at: examples, withIntermediateDirectories: true)
    let flat = Data(#"{ "id": "multishell.dark", "name": "Old", "ansi": [] }"#.utf8)
    let strays = [directory, examples].map { place in
      place.appendingPathComponent("example.multishell.dark.json")
    }
    for stray in strays { try flat.write(to: stray) }

    let catalogue = ThemeCatalogue.loadRemovingStrayExamples(from: directory)

    #expect(Set(catalogue.themes.map(\.id)) == Set(Theme.builtins.map(\.id)))
    #expect(catalogue.problems.isEmpty)
    #expect(!strays.contains { FileManager.default.fileExists(atPath: $0.path) })
  }

  @Test func examplesAreWrittenBesideTheThemesNotAmongThem() throws {
    let directory = try Scratch.directory("themes")
    defer { Scratch.remove(directory) }

    try ThemeCatalogue.seedExamples(in: directory)

    #expect(
      Set(ThemeCatalogue.loadRemovingStrayExamples(from: directory).themes.map(\.id))
        == Set(Theme.builtins.map(\.id))
    )
    let examples = try FileManager.default.contentsOfDirectory(
      atPath: directory.appendingPathComponent("examples").path
    ).sorted()
    #expect(examples == Theme.builtins.map { "\($0.id).json" }.sorted())
  }

  @Test func anExampleIsACopyOfItsBuiltInThemeAndOneThatDiffersIsRewritten() throws {
    let directory = try Scratch.directory("themes")
    defer { Scratch.remove(directory) }
    let examples = directory.appendingPathComponent("examples")
    try FileManager.default.createDirectory(at: examples, withIntermediateDirectories: true)
    let stale = examples.appendingPathComponent("multishell.dark.json")
    try Data(#"{ "id": "multishell.dark", "name": "Old" }"#.utf8).write(to: stale)

    try ThemeCatalogue.seedExamples(in: directory)

    for theme in Theme.builtins {
      let source = try #require(Theme.builtinFile(named: theme.id))
      let example = examples.appendingPathComponent("\(theme.id).json")
      #expect(try Data(contentsOf: example) == Data(contentsOf: source), "\(theme.id)")
    }
  }

  @Test func aHiddenFileSuchAsAnEditorsLockIsNotReadAsATheme() throws {
    let directory = try Scratch.directory("themes")
    defer { Scratch.remove(directory) }
    try Data("{".utf8).write(to: directory.appendingPathComponent(".#mine.json"))

    let catalogue = ThemeCatalogue.loadRemovingStrayExamples(from: directory)

    #expect(catalogue.problems.isEmpty)
  }
}
