import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// The bytes of the file: what a read refuses and what a write keeps.
@Suite
struct AgentHookIntegrationInstallingTests: AgentHookFixtures {
  /// The file is the user's. A parse to doubles and back writes `0.1` as
  /// `0.10000000000000001` and `1.0` as `1`, so numbers are kept as written.
  @Test func installingKeepsEveryNumberInTheFileAsTheUserWroteIt() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("settings.json")
    try #"{"a": 1.0, "c": 0.1, "big": 12345678901234567890123, "e": 1e-7, "s": "1.0", "hooks": {}}"#
      .write(to: file, atomically: true, encoding: .utf8)

    try AgentHookCatalogue.claude.install(into: file, helper: helper)
    let installed = try String(contentsOf: file, encoding: .utf8)
    for kept in [#""a" : 1.0"#, #""c" : 0.1"#, #""big" : 12345678901234567890123"#, #""e" : 1e-7"#]
    {
      #expect(installed.contains(kept), "\(installed)")
    }
    #expect(installed.contains(#""s" : "1.0""#), "a string that looks like one is still a string")
    #expect(installed.contains("\\u0001") == false, "and no marker leaks into the file")
    #expect(installed.contains(#""timeout" : 5"#), "our own numbers are written as before")

    try AgentHookCatalogue.claude.remove(from: file)
    let removed = try String(contentsOf: file, encoding: .utf8)
    #expect(removed.contains(#""c" : 0.1"#) && removed.contains(#""a" : 1.0"#), "\(removed)")
  }

  /// Keeping numbers as written must not widen what a read accepts.
  @Test func aNumberThatIsNotJSONOrAFileThatIsNotUTF8IsStillRefused() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("settings.json")
    for literal in ["01", "1-2", "-", "1e", "1.e5", "+1", ".5", "1."] {
      let theirs = #"{"a": \#(literal), "hooks": {}}"#
      try theirs.write(to: file, atomically: true, encoding: .utf8)
      #expect(throws: UnparsableSettingsFile.self, "\(literal)") {
        try AgentHookCatalogue.claude.install(into: file, helper: helper)
      }
      #expect(try String(contentsOf: file, encoding: .utf8) == theirs, "\(literal): untouched")
    }

    var latin1 = Data(#"{"a": ""#.utf8)
    latin1.append(contentsOf: [0xE9])
    latin1.append(contentsOf: Data(#"", "hooks": {}}"#.utf8))
    try latin1.write(to: file)
    #expect(throws: UnparsableSettingsFile.self) {
      try AgentHookCatalogue.claude.install(into: file, helper: helper)
    }
    #expect(try Data(contentsOf: file) == latin1, "untouched")
  }

  @Test func aFileThatIsNotAnObjectIsRefusedNotRewritten() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("settings.json")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try "[1, 2, 3]".write(to: file, atomically: true, encoding: .utf8)

    #expect(throws: UnexpectedSettingsShape.self) {
      try AgentHookCatalogue.gemini.install(into: file, helper: helper)
    }
    #expect(try String(contentsOf: file, encoding: .utf8) == "[1, 2, 3]")
    #expect(!AgentHookCatalogue.gemini.isInstalled(in: file))
  }

  /// Gemini's settings file takes comments and Gemini keeps them when it writes the file, so a
  /// strict rewrite would throw them away.
  @Test func aFileWithCommentsIsRefusedRatherThanRewrittenWithoutThem() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("settings.json")
    let commented = """
      {
        // the model I use everywhere
        "theme": "Default",
        "hooks": {}
      }
      """
    try commented.write(to: file, atomically: true, encoding: .utf8)

    #expect(throws: UnparsableSettingsFile.self) {
      try AgentHookCatalogue.gemini.install(into: file, helper: helper)
    }
    #expect(try String(contentsOf: file, encoding: .utf8) == commented, "comments and all")
    #expect(!AgentHookCatalogue.gemini.isInstalled(in: file))
    #expect(
      !FileManager.default.fileExists(
        atPath: file.appendingPathExtension("before-multishell").path),
      "nothing was written, so nothing was backed up")
  }

  /// A settings file is often a symlink into a dotfiles repository, and an atomic write puts a
  /// regular file where the link was.
  @Test func aSymlinkedSettingsFileIsWrittenThroughRatherThanReplaced() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let dotfiles = directory.appendingPathComponent("dotfiles", isDirectory: true)
    let home = directory.appendingPathComponent("home/.claude", isDirectory: true)
    try FileManager.default.createDirectory(at: dotfiles, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    let tracked = dotfiles.appendingPathComponent("settings.json")
    try #"{ "model": "opus" }"#.write(to: tracked, atomically: true, encoding: .utf8)
    let link = home.appendingPathComponent("settings.json")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: tracked)

    try AgentHookCatalogue.claude.install(into: link, helper: helper)

    #expect(
      (try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) == tracked.path,
      "still a link, so the dotfiles repository still owns the file")
    #expect(
      AgentHookCatalogue.claude.isInstalled(in: tracked), "written through to what it points at")
    #expect(try AgentSettingsFile.read(tracked)["model"] as? String == "opus")

    // The copy goes beside the link, where the user will look for it, not
    // into the repository the link points into.
    #expect(
      try String(contentsOf: link.appendingPathExtension("before-multishell"), encoding: .utf8)
        .contains("opus"))
    #expect(
      !FileManager.default.fileExists(
        atPath: tracked.appendingPathExtension("before-multishell").path),
      "nothing new in the dotfiles repository for git to report")

    try AgentHookCatalogue.claude.remove(from: link)
    #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) != nil)
    #expect(!AgentHookCatalogue.claude.isInstalled(in: tracked))
  }

  @Test func anEmptyFileReadsAsNoSettings() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("settings.json")
    try "\n".write(to: file, atomically: true, encoding: .utf8)
    #expect(try AgentSettingsFile.read(file).isEmpty)
  }
}
