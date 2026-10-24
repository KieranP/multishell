import Testing

@testable import MultishellCore

@Suite
struct InheritedShellStateTests {
  @Test func theStateAShellsToolsKeepAboutItsOwnSessionIsNamedForDropping() {
    let environment = [
      "__MISE_ORIG_PATH": "/usr/bin:/Applications/Multishell.app/Contents/MacOS",
      "__MISE_DIFF": "x",
      "__MISE_SESSION": "y",
      "DIRENV_DIFF": "z",
      "DIRENV_DIR": "-/w",
      "DIRENV_LOG_FORMAT": "",
      "MISE_DATA_DIR": "/m",
      "__CF_USER_TEXT_ENCODING": "0x1F5:0x0:0x0",
      "PATH": "/usr/bin",
    ]

    #expect(
      InheritedShellState.names(in: environment)
        == ["DIRENV_DIFF", "DIRENV_DIR", "__MISE_DIFF", "__MISE_ORIG_PATH", "__MISE_SESSION"]
    )
  }

  @Test func whatALaunchingAgentsCustomCommandExportedIsNamedForDropping() {
    let environment = [
      "MULTISHELL_BRANCH": "b", "MULTISHELL_WORKTREE_NAME": "n", "MULTISHELL_WORKTREE_PATH": "/w",
      "MULTISHELL_PROJECT_NAME": "p", "MULTISHELL_PROJECT_PATH": "/p", "MULTISHELL_TASK": "t",
    ]

    #expect(InheritedShellState.names(in: environment) == environment.keys.sorted())
  }

  @Test func whatTheLaunchingPaneWasGivenIsNamedForDroppingAndATestsSocketKept() {
    let environment = [
      "MULTISHELL_PORT": "3000", "MULTISHELL_SOCKET": "/s", "MULTISHELL_SESSION": "id",
      "MULTISHELL_WORKTREE": "/w", "MULTISHELL_APP_PID": "1", "MULTISHELL_LEADING_PATH": "/b",
      "MULTISHELL_CONTROL_SOCKET": "/c",
    ]

    #expect(
      InheritedShellState.names(in: environment) == [
        "MULTISHELL_APP_PID", "MULTISHELL_LEADING_PATH", "MULTISHELL_PORT", "MULTISHELL_SESSION",
        "MULTISHELL_SOCKET", "MULTISHELL_WORKTREE",
      ]
    )
  }
}
