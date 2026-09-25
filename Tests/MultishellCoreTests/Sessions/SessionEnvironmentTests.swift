import Foundation
import Testing

@testable import MultishellCore

struct SessionEnvironmentTests {
  @Test func theEnvironmentNamesTheSessionTheWorktreeAndTheSocket() {
    let session = TerminalSession(
      worktreeID: "/w", workingDirectory: URL(fileURLWithPath: "/w/repo"), title: "Shell")
    let variables = SessionEnvironment.variables(
      for: session, socket: URL(fileURLWithPath: "/state/multishell.sock"))
    #expect(variables["MULTISHELL_SESSION"] == session.id.uuidString)
    #expect(variables["MULTISHELL_WORKTREE"] == "/w/repo")
    #expect(variables["MULTISHELL_SOCKET"] == "/state/multishell.sock")
    #expect(
      variables["MULTISHELL_APP_PID"] == String(ProcessInfo.processInfo.processIdentifier),
      "so the helper's walk up from a prompt knows where to stop")
  }

  @Test func theBaseVariablesStandWhicheverShellTheTabRuns() {
    for shell in ["/bin/zsh", "/bin/bash", "/opt/homebrew/bin/fish"] {
      let session = TerminalSession(
        worktreeID: "/w", workingDirectory: URL(fileURLWithPath: "/w/repo"), title: "Shell",
        shellOverride: shell)
      let variables = SessionEnvironment.variables(for: session, socket: URL(fileURLWithPath: "/s"))
      #expect(variables[SessionEnvironment.sessionKey] == session.id.uuidString, "\(shell)")
      #expect(variables[SessionEnvironment.workingDirectoryKey] == "/w/repo", "\(shell)")
      #expect(variables[SessionEnvironment.socketKey] == "/s", "\(shell)")
      #expect(variables[SessionEnvironment.appPIDKey] != nil, "\(shell)")
    }
  }
}
