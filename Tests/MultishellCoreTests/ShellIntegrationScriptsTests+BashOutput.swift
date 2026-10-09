import Foundation
import Testing

@testable import MultishellCore

/// A real bash run against the generated init file, as a Ghostty pane starts
/// it, with the user's own `.bashrc` read on the way.
extension ShellIntegrationScriptsTests {
  func bashOutput(
    _ bash: String,
    features: String?,
    input: String,
    usersRC: String,
  ) async throws -> String {
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", usersRC)
    var environment = files.environment(termProgram: "ghostty")
    environment["GHOSTTY_SHELL_FEATURES"] = features
    environment[SessionEnvironment.sessionVariable] = "bash-output"
    environment[SessionEnvironment.worktreeVariable] = "/w"
    return try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input: input,
    )
  }
}
