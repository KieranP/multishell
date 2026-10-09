import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct ThemeCatalogueTests {
  @Test func userFilesAreAddedAndCanReplaceBuiltins() throws {
    let directory = try Scratch.directory("themes")
    defer { Scratch.remove(directory) }

    var custom = Theme.multishellDark
    custom.id = "user.custom"
    custom.name = "Custom"
    var override = Theme.multishellLight
    override.name = "Light, but mine"
    for theme in [custom, override] {
      try JSONEncoder().encode(theme).write(
        to: directory.appendingPathComponent("\(theme.id).json")
      )
    }
    try Data("{".utf8).write(to: directory.appendingPathComponent("broken.json"))

    let catalogue = ThemeCatalogue.loadMovingStrayExamples(from: directory)

    #expect(catalogue.themes.map(\.id) == ["multishell.dark", "multishell.light", "user.custom"])
    #expect(catalogue.themes.first { $0.id == Theme.multishellLight.id }?.name == "Light, but mine")
    #expect(catalogue.problems.count == 1)
  }

  @Test func aThemeFileWithTooFewColoursIsAProblemNotACrash() throws {
    let directory = try Scratch.directory("themes")
    defer { Scratch.remove(directory) }
    var short = Theme.multishellDark
    short.id = "user.short"
    short.ansi = Array(short.ansi.prefix(8))
    try JSONEncoder().encode(short).write(to: directory.appendingPathComponent("short.json"))

    let catalogue = ThemeCatalogue.loadMovingStrayExamples(from: directory)

    #expect(catalogue.themes.map(\.id) == Theme.builtins.map(\.id))
    #expect(catalogue.problems.count == 1)
    #expect(catalogue.problems[0].hasPrefix("short.json:"))
    #expect(catalogue.themes.allSatisfy { $0.ansi.count == 16 })
  }

  @Test func loadingAloneMovesStrayExamplesIntoTheExamplesFolder() throws {
    let directory = try Scratch.directory("themes")
    defer { Scratch.remove(directory) }
    try JSONEncoder().encode(Theme.multishellDark).write(
      to: directory.appendingPathComponent("example.multishell.dark.json")
    )

    let catalogue = ThemeCatalogue.loadMovingStrayExamples(from: directory)

    #expect(catalogue.themes.count == Theme.builtins.count)
    #expect(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("examples/example.multishell.dark.json").path
      )
    )
  }

  @Test func examplesAreWrittenBesideTheThemesNotAmongThem() throws {
    let directory = try Scratch.directory("themes")
    defer { Scratch.remove(directory) }
    // A leftover from the earlier layout, which loaded as a duplicate.
    try JSONEncoder().encode(Theme.multishellDark).write(
      to: directory.appendingPathComponent("example.multishell.dark.json")
    )

    try ThemeCatalogue.seedExamples(in: directory)

    #expect(
      ThemeCatalogue.loadMovingStrayExamples(from: directory).themes.map(\.id)
        == Theme.builtins.map(\.id)
    )
    let examples = try FileManager.default.contentsOfDirectory(
      atPath: directory.appendingPathComponent("examples").path
    ).sorted()
    #expect(
      examples == ["example.multishell.dark.json", "multishell.dark.json", "multishell.light.json"]
    )
  }
}
