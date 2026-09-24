import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct AnyShellQuotingTests {
  @Test(arguments: ["/bin/sh", "/bin/zsh", "/bin/bash", "/bin/dash", "/bin/tcsh"])
  func aWordQuotedForAnyShellReadsTheSameInEach(shell: String) throws {
    guard FileManager.default.isExecutableFile(atPath: shell) else { return }
    let words = [#"a\"#, "it's", #"\'"#, #"back\slash"#, "My Projects", "$HOME", "plain"]
    let process = Process()
    process.executableURL = URL(fileURLWithPath: shell)
    process.arguments = [
      "-c",
      "/usr/bin/printf '%s\\n' " + words.map(AnyShellQuoting.quote).joined(separator: " "),
    ]
    process.environment = ["PATH": "/usr/bin:/bin", "HISTFILE": ""]
    let pipe = Pipe()
    process.standardOutput = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    #expect(String(decoding: data, as: UTF8.self) == words.map { $0 + "\n" }.joined())
  }

  @Test(arguments: [
    ("/bin/tcsh", ["-f", "-i"]), ("/bin/bash", ["--norc", "-i"]), ("/bin/zsh", ["-f", "-i"]),
  ])
  func aWordForAnyShellSurvivesATypedLinesHistoryExpansion(
    shell: String, flags: [String]
  ) throws {
    guard FileManager.default.isExecutableFile(atPath: shell) else { return }
    let home = try Scratch.directory("quoting")
    defer { Scratch.remove(home) }
    let word = "a!b.txt"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: shell)
    process.arguments = flags
    process.environment = ["PATH": "/usr/bin:/bin", "HISTFILE": "", "HOME": home.path]
    let input = Pipe()
    let output = Pipe()
    process.standardInput = input
    process.standardOutput = output
    process.standardError = output
    try process.run()
    input.fileHandleForWriting.write(
      Data("/usr/bin/printf '[%s]\\n' \(AnyShellQuoting.quote(word))\nexit\n".utf8))
    try input.fileHandleForWriting.close()
    let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    process.waitUntilExit()

    #expect(text.contains("[\(word)]"), "\(text)")
  }

  @Test func aWordForAnyShellPutsEachBackslashOutsideTheQuotes() {
    #expect(AnyShellQuoting.quote(#"a\"#) == #"'a'\\''"#)
    #expect(AnyShellQuoting.quote("it's") == #"'it'\''s'"#)
    #expect(AnyShellQuoting.quote("/plain/path") == "/plain/path")
  }
}
