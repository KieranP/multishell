import Foundation
import Testing

@testable import MultishellCore

struct SessionEnvironmentTests {
  @Test func theEnvironmentNamesTheSessionTheWorktreeAndTheSocket() {
    let session = TerminalSession(
      worktreeID: "/w",
      workingDirectory: URL(fileURLWithPath: "/w/repo"),
      title: "Shell",
    )
    let variables = SessionEnvironment.variables(
      for: session,
      socket: URL(fileURLWithPath: "/state/multishell.sock"),
    )
    #expect(variables["MULTISHELL_SESSION"] == session.id.uuidString)
    #expect(variables["MULTISHELL_WORKTREE"] == "/w/repo")
    #expect(variables["MULTISHELL_SOCKET"] == "/state/multishell.sock")
    #expect(
      variables["MULTISHELL_APP_PID"] == String(ProcessInfo.processInfo.processIdentifier),
      "so the helper's walk up from a prompt knows where to stop",
    )
  }

  @Test func aSessionWithAPortGetsItAsMultishellPortAndOneWithoutGetsNone() {
    var session = TerminalSession(
      worktreeID: "/w",
      workingDirectory: URL(fileURLWithPath: "/w/repo"),
      title: "Shell",
    )
    let socket = URL(fileURLWithPath: "/s")
    #expect(SessionEnvironment.variables(for: session, socket: socket)["MULTISHELL_PORT"] == nil)

    session.port = 3010

    #expect(
      SessionEnvironment.variables(for: session, socket: socket)["MULTISHELL_PORT"] == "3010"
    )
  }

  @Test func theBaseVariablesStandWhicheverShellTheTabRuns() {
    for shell in ["/bin/zsh", "/bin/bash", "/opt/homebrew/bin/fish"] {
      let session = TerminalSession(
        worktreeID: "/w",
        workingDirectory: URL(fileURLWithPath: "/w/repo"),
        title: "Shell",
        shellOverride: shell,
      )
      let variables = SessionEnvironment.variables(
        for: session,
        socket: URL(fileURLWithPath: "/s"),
      )
      #expect(variables[SessionEnvironment.sessionVariable] == session.id.uuidString, "\(shell)")
      #expect(variables[SessionEnvironment.worktreeVariable] == "/w/repo", "\(shell)")
      #expect(variables[SessionEnvironment.socketVariable] == "/s", "\(shell)")
      #expect(variables[SessionEnvironment.appPIDVariable] != nil, "\(shell)")
    }
  }

  @Test func theHelpersDirectoryLeadsJustAheadOfTheAppsWhichTheEngineWouldAppend() {
    let session = TerminalSession(
      worktreeID: "/w",
      workingDirectory: URL(fileURLWithPath: "/w"),
      title: "",
    )
    let bundle = BundleDirectories(
      helper: URL(fileURLWithPath: "/A.app/Contents/Helpers"),
      app: URL(fileURLWithPath: "/A.app/Contents/MacOS"),
    )

    let variables = SessionEnvironment.variables(
      for: session,
      socket: URL(fileURLWithPath: "/s"),
      bundle: bundle,
      inheritedPath: "/usr/bin:/A.app/Contents/MacOS:/bin",
    )

    #expect(variables["PATH"] == "/A.app/Contents/Helpers:/A.app/Contents/MacOS:/usr/bin:/bin")
  }

  @Test func theLeadingEntriesAreNamedForTheShellToPutBackAfterItsProfile() {
    let session = TerminalSession(
      worktreeID: "/w",
      workingDirectory: URL(fileURLWithPath: "/w"),
      title: "",
    )
    let bundle = BundleDirectories(
      helper: URL(fileURLWithPath: "/A.app/Contents/Helpers"),
      app: URL(fileURLWithPath: "/A.app/Contents/MacOS"),
    )

    let variables = SessionEnvironment.variables(
      for: session,
      socket: URL(fileURLWithPath: "/s"),
      bundle: bundle,
      inheritedPath: "/usr/bin",
    )

    #expect(
      variables[SessionEnvironment.leadingPathVariable]
        == "/A.app/Contents/Helpers:/A.app/Contents/MacOS"
    )
  }

  @Test func theHelperComesAheadOfAnotherBuildsAppOnAPathInheritedFromItsPane() {
    let session = TerminalSession(
      worktreeID: "/w",
      workingDirectory: URL(fileURLWithPath: "/w"),
      title: "",
    )
    let bundle = BundleDirectories(
      helper: URL(fileURLWithPath: "/build/A.app/Contents/Helpers"),
      app: URL(fileURLWithPath: "/build/A.app/Contents/MacOS"),
    )

    let variables = SessionEnvironment.variables(
      for: session,
      socket: URL(fileURLWithPath: "/s"),
      bundle: bundle,
      inheritedPath: "/usr/bin:/Applications/A.app/Contents/MacOS:/bin",
    )

    let path = variables["PATH"]?.split(separator: ":").map(String.init) ?? []
    let helper = path.firstIndex(of: "/build/A.app/Contents/Helpers")
    let other = path.firstIndex(of: "/Applications/A.app/Contents/MacOS")
    #expect(helper != nil && other != nil && helper! < other!, "\(path)")
  }

  @Test func withNoBundleThePathIsLeftToTheEngine() {
    let session = TerminalSession(
      worktreeID: "/w",
      workingDirectory: URL(fileURLWithPath: "/w"),
      title: "",
    )

    #expect(
      SessionEnvironment.variables(for: session, socket: URL(fileURLWithPath: "/s"))["PATH"] == nil
    )
  }
}
