import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct ShellLineTests {
  private func run(
    _ shell: String,
    _ line: ShellLine,
    in directory: URL,
    environment: [String: String] = Scratch.shellEnvironment,
  ) async throws -> String {
    let command = line.prefixing([shell, "-c", line.text])
    return try await Detached.output(
      of: command[0],
      Array(command.dropFirst()),
      environment: environment,
      in: directory,
      standardError: .discarded,
    )
  }

  @Test(
    arguments: InstalledShells.only(["/bin/zsh", "/bin/bash", "/bin/sh", "/bin/tcsh", "/bin/dash"]),
    ["feat$(date>ran)", "feat`date>ran`'\"x  y"],
  )
  func aPlaceholderTheUserQuotedStillArrivesAsText(shell: String, hostile: String) async throws {
    let directory = try Scratch.directory("custom-line")
    defer { Scratch.remove(directory) }
    let expectations = [
      "printf '%s|' {{branch}}": "\(hostile)|",
      "printf '%s|' \"on {{branch}}\"": "on \(hostile)|",
      "printf '%s|' 'on {{branch}}'": "on \(hostile)|",
      "printf '%s|' \"{{branch}}\"x": "\(hostile)x|",
      "printf '%s|' {{branch}}{{branch}}": "\(hostile)\(hostile)|",
    ]
    for (template, expected) in expectations {
      let line = AgentCatalogue.customCommandLine(
        template,
        values: WorktreePlaceholder.sampleValues(branch: hostile),
        forShellNamed: shell.executableName,
      )
      #expect(try await run(shell, line, in: directory) == expected, "\(template)")
    }
    #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("ran").path))
  }

  @Test(
    arguments: InstalledShells.only(["/bin/zsh", "/bin/bash", "/bin/sh", "/bin/tcsh", "/bin/dash"])
  )
  func theEditorsPathArrivesAsTextWhereverItIsWritten(shell: String) async throws {
    let directory = try Scratch.directory("custom-editor")
    defer { Scratch.remove(directory) }
    let path = URL(fileURLWithPath: "/w/feat$(date>ran) 'x\"")
    let expectations = [
      "printf '%s|' {path}": "\(path.path)|",
      "printf '%s|' \"{path}\"": "\(path.path)|",
      "printf '%s|' '{path}'": "\(path.path)|",
      "printf '%s|'": "\(path.path)|",
    ]
    for (template, expected) in expectations {
      let line = try #require(
        EditorCatalogue.customCommandLine(
          template,
          path: path,
          forShellNamed: shell.executableName,
        )
      )
      #expect(try await run(shell, line, in: directory) == expected, "\(template)")
    }
    #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("ran").path))
  }

  @Test(arguments: InstalledShells.fishes)
  func fishReadsEachPlaceholderAsTextWithItsOwnEscapesInSingleQuotes(shell: String) async throws {
    let directory = try Scratch.directory("custom-line-fish")
    defer { Scratch.remove(directory) }
    let hostile = "feat$(date>ran) 'x\\"
    let expectations = [
      "printf '%s|' {{task}}": "\(hostile)|",
      "printf '%s|' \"on {{task}}\"": "on \(hostile)|",
      "printf '%s|' 'on {{task}}'": "on \(hostile)|",
      "printf '%s|' \"{{task}}\"x": "\(hostile)x|",
      #"printf '%s|' 'it\'s {{task}}'"#: "it's \(hostile)|",
      #"printf '%s|' 'a\\' {{task}}"#: "a\\|\(hostile)|",
    ]
    for (template, expected) in expectations {
      let line = AgentCatalogue.customCommandLine(
        template,
        values: [:],
        forShellNamed: "fish",
        task: hostile,
      )
      let output = try await run(
        shell,
        line,
        in: directory,
        environment: Scratch.bareShellEnvironment(home: directory),
      )
      #expect(output == expected, "\(template)")
    }
    #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("ran").path))
  }
}
