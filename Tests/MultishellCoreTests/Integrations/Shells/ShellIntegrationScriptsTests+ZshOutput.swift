import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// A real zsh run against the generated files, as a Ghostty pane starts it.
extension ShellIntegrationScriptsTests {
  static let zshPath = "/bin/zsh"
  static let scriptProgramPath = "/usr/bin/script"

  func zshOutput(
    features: String?, input: String, usersRC: String? = nil, arguments: [String] = ["-i"],
    helper: String = "/bin/echo"
  ) async throws -> String {
    try #require(FileManager.default.isExecutableFile(atPath: Self.zshPath))
    let files = try GeneratedIntegration(helper: helper)
    defer { files.tearDown() }
    if let usersRC { try files.writeHomeFile(".zshrc", usersRC) }
    var environment = files.environment(termProgram: "ghostty")
    environment["ZDOTDIR"] = files.zshDirectory.path
    environment["GHOSTTY_SHELL_FEATURES"] = features
    environment[SessionEnvironment.sessionVariable] = "zsh-output"
    environment[SessionEnvironment.worktreeVariable] = "/w"
    environment[SessionEnvironment.socketVariable] = files.root.appendingPathComponent("s").path
    let script = files.home.appendingPathComponent("script.zsh")
    try Data(input.utf8).write(to: script)
    return try await interactiveShellOutput(
      Self.zshPath, arguments: arguments.map { $0 == "SCRIPT" ? script.path : $0 },
      environment: environment, input: input)
  }

  /// zle loads with a terminal, which a test's piped shell has none of, so
  /// the modules are loaded by hand before the generated file is read.
  func zleOutput(
    features: String, before: String = "", after: String
  ) async throws
    -> String
  {
    try #require(FileManager.default.isExecutableFile(atPath: Self.zshPath))
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    let zshrc = files.zshDirectory.appendingPathComponent(".zshrc").path
    let script = """
      zmodload zsh/zle zsh/zleparameter
      \(before)
      source \(PosixShellQuoting.quote(zshrc))
      \(after)
      """
    var environment = files.environment(termProgram: "ghostty")
    environment["GHOSTTY_SHELL_FEATURES"] = features
    return try await Detached.output(
      of: Self.zshPath, ["-f", "-c", script], environment: environment)
  }

  /// The generated file read in a zsh on a terminal of its own, which `script`
  /// gives it, after a first prompt, which a `-c` shell never shows.
  func terminalOutput(after: String) async throws -> String {
    try #require(FileManager.default.isExecutableFile(atPath: Self.scriptProgramPath))
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    let zshrc = files.zshDirectory.appendingPathComponent(".zshrc").path
    let script = """
      source \(PosixShellQuoting.quote(zshrc))
      _multishell_prompted=1
      \(after)
      """
    return try await Detached.output(
      of: Self.scriptProgramPath, ["-q", "/dev/null", Self.zshPath, "-f", "-c", script],
      environment: files.environment(termProgram: "ghostty"))
  }
}
