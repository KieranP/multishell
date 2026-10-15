import Foundation
import Testing

@testable import MultishellCore

@Suite
struct EditorCatalogueCustomCommandTests {
  @Test func theCustomTemplateReadsThePathFromTheEnvironmentWhereThePlaceholderIs() {
    let worktree = EditorTarget.worktree(URL(fileURLWithPath: "/Users/me/My Work/repo"))
    let environment = ["MULTISHELL_WORKTREE_PATH": "/Users/me/My Work/repo"]
    #expect(
      EditorCatalogue.customCommandLine(
        "code-insiders {path}",
        target: worktree,
        forShellNamed: "zsh",
      )
        == ShellLine(text: #"code-insiders "$MULTISHELL_WORKTREE_PATH""#, environment: environment)
    )
    #expect(
      EditorCatalogue.customCommandLine("  micro  ", target: worktree, forShellNamed: "zsh")
        == ShellLine(text: #"micro "$MULTISHELL_WORKTREE_PATH""#, environment: environment),
      "no placeholder: the path is appended",
    )
    #expect(EditorCatalogue.customCommandLine("  ", target: worktree, forShellNamed: "zsh") == nil)
    #expect(
      EditorCatalogue.customCommandLine(
        "open -a X {path} && echo {path}",
        target: worktree,
        forShellNamed: "zsh",
      )?.text
        == #"open -a X "$MULTISHELL_WORKTREE_PATH" && echo "$MULTISHELL_WORKTREE_PATH""#
    )
  }

  @Test func aFilesPathComesFromItsOwnVariableNotTheWorktrees() {
    let file = URL(fileURLWithPath: "/Users/me/My Work/repo/run.py")
    #expect(
      EditorCatalogue.customCommandLine(
        "code-insiders {path}",
        target: .file(file),
        forShellNamed: "zsh",
      )
        == ShellLine(
          text: #"code-insiders "$MULTISHELL_FILE_PATH""#,
          environment: ["MULTISHELL_FILE_PATH": file.path],
        )
    )
  }
}
