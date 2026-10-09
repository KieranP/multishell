import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct ShellLineTests {
  private func run(_ shell: String, _ line: ShellLine, in directory: URL) async throws -> String {
    let command = line.prefixing([shell, "-c", line.text])
    return try await Detached.output(
      of: command[0],
      Array(command.dropFirst()),
      environment: Scratch.shellEnvironment,
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
      let line = try #require(EditorCatalogue.customCommandLine(template, path: path))
      #expect(try await run(shell, line, in: directory) == expected, "\(template)")
    }
    #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("ran").path))
  }
}
