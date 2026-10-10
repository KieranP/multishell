import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// A real fish run against the generated init file, as a Ghostty pane starts
/// it, with the user's own `config.fish` read on the way.
extension ShellIntegrationScriptsTests {
  func fishOutput(
    _ fish: String,
    features: String?,
    input: String,
    usersConfig: String = "",
    termProgram: String? = "ghostty",
  ) async throws -> String {
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try FileManager.default.createDirectory(
      at: files.home.appendingPathComponent(".config/fish"),
      withIntermediateDirectories: true,
    )
    try files.writeHomeFile(".config/fish/config.fish", usersConfig)
    var environment = files.environment(termProgram: termProgram)
    environment["GHOSTTY_SHELL_FEATURES"] = features
    let launch = ShellLaunch.fishInitArguments(forShell: fish, fishInit: files.fishInit)
    return try await interactiveShellOutput(
      fish,
      arguments: Array(launch.dropFirst()) + ["-i"],
      environment: environment,
      input: input,
    )
  }
}
