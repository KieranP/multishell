import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct ShellLineTests {
  private let project = Project(path: URL(fileURLWithPath: "/repos/demo"))

  private func values(branch: String) -> [AgentPlaceholder: String] {
    let worktree = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-worktrees/w"), projectID: project.id, head: "a",
      branch: branch)
    return AgentPlaceholder.values(project: project, worktree: worktree, worktreeName: branch)
  }

  private func run(_ shell: String, _ line: ShellLine, in directory: URL) throws -> String {
    let command = line.prefixing([shell, "-c", line.text])
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command[0])
    process.arguments = Array(command.dropFirst())
    process.currentDirectoryURL = directory
    let output = Pipe()
    process.standardOutput = output
    try process.run()
    process.waitUntilExit()
    return String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
  }

  @Test(
    arguments: ["/bin/zsh", "/bin/bash", "/bin/sh", "/bin/tcsh", "/bin/dash"],
    ["feat$(date>ran)", "feat`date>ran`'\"x  y"])
  func aPlaceholderTheUserQuotedStillArrivesAsText(shell: String, hostile: String) throws {
    guard FileManager.default.isExecutableFile(atPath: shell) else { return }
    let directory = try Scratch.directory("custom-line")
    defer { try? FileManager.default.removeItem(at: directory) }
    let expectations = [
      "printf '%s|' {{branch}}": "\(hostile)|",
      "printf '%s|' \"on {{branch}}\"": "on \(hostile)|",
      "printf '%s|' 'on {{branch}}'": "on \(hostile)|",
      "printf '%s|' \"{{branch}}\"x": "\(hostile)x|",
      "printf '%s|' {{branch}}{{branch}}": "\(hostile)\(hostile)|",
    ]
    for (template, expected) in expectations {
      let line = AgentCatalogue.customCommandLine(template, values: values(branch: hostile))
      #expect(try run(shell, line, in: directory) == expected, "\(template)")
    }
    #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("ran").path))
  }

  @Test(arguments: ["/bin/zsh", "/bin/bash", "/bin/sh", "/bin/tcsh", "/bin/dash"])
  func theEditorsPathArrivesAsTextWhereverItIsWritten(shell: String) throws {
    guard FileManager.default.isExecutableFile(atPath: shell) else { return }
    let directory = try Scratch.directory("custom-editor")
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = URL(fileURLWithPath: "/w/feat$(date>ran) 'x\"")
    let expectations = [
      "printf '%s|' {path}": "\(path.path)|",
      "printf '%s|' \"{path}\"": "\(path.path)|",
      "printf '%s|' '{path}'": "\(path.path)|",
      "printf '%s|'": "\(path.path)|",
    ]
    for (template, expected) in expectations {
      let line = try #require(EditorCatalogue.customCommandLine(template, path: path))
      #expect(try run(shell, line, in: directory) == expected, "\(template)")
    }
    #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("ran").path))
  }
}
