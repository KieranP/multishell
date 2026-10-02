import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct AnyShellQuotingTests {
  @Test(arguments: ["/bin/sh", "/bin/zsh", "/bin/bash", "/bin/dash", "/bin/tcsh"])
  func aWordQuotedForAnyShellReadsTheSameInEach(shell: String) async throws {
    guard FileManager.default.isExecutableFile(atPath: shell) else { return }
    let words = [#"a\"#, "it's", #"\'"#, #"back\slash"#, "My Projects", "$HOME", "plain"]
    let output = try await Detached.output(
      of: shell,
      ["-c", "/usr/bin/printf '%s\\n' " + words.map(AnyShellQuoting.quote).joined(separator: " ")],
      environment: ["PATH": "/usr/bin:/bin", "HISTFILE": ""], standardError: .discarded)

    #expect(output == words.map { $0 + "\n" }.joined())
  }

  @Test(arguments: [
    ("/bin/tcsh", ["-f", "-i"]), ("/bin/bash", ["--norc", "-i"]), ("/bin/zsh", ["-f", "-i"]),
  ])
  func aWordForAnyShellSurvivesATypedLinesHistoryExpansion(
    shell: String, flags: [String]
  ) async throws {
    guard FileManager.default.isExecutableFile(atPath: shell) else { return }
    let home = try Scratch.directory("quoting")
    defer { Scratch.remove(home) }
    let word = "a!b.txt"
    let text = try await Detached.output(
      of: shell, flags, environment: Scratch.bareShellEnvironment(home: home),
      input: "/usr/bin/printf '[%s]\\n' \(AnyShellQuoting.quote(word))\nexit\n")

    #expect(text.contains("[\(word)]"), "\(text)")
  }

  @Test func aWordForAnyShellPutsEachBackslashOutsideTheQuotes() {
    #expect(AnyShellQuoting.quote(#"a\"#) == #"'a'\\''"#)
    #expect(AnyShellQuoting.quote("it's") == #"'it'\''s'"#)
    #expect(AnyShellQuoting.quote("/plain/path") == "/plain/path")
  }
}
