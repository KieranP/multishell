import Foundation
import Testing

@testable import MultishellCore

@Suite
struct EditorCatalogueCustomCommandTests {
  @Test func theCustomTemplateReadsThePathFromTheEnvironmentWhereThePlaceholderIs() {
    let path = URL(fileURLWithPath: "/Users/me/My Work/repo")
    let environment = ["MULTISHELL_WORKTREE_PATH": "/Users/me/My Work/repo"]
    #expect(
      EditorCatalogue.customCommandLine("code-insiders {path}", path: path)
        == ShellLine(text: #"code-insiders "$MULTISHELL_WORKTREE_PATH""#, environment: environment)
    )
    #expect(
      EditorCatalogue.customCommandLine("  micro  ", path: path)
        == ShellLine(text: #"micro "$MULTISHELL_WORKTREE_PATH""#, environment: environment),
      "no placeholder: the path is appended",
    )
    #expect(EditorCatalogue.customCommandLine("  ", path: path) == nil)
    #expect(
      EditorCatalogue.customCommandLine("open -a X {path} && echo {path}", path: path)?.text
        == #"open -a X "$MULTISHELL_WORKTREE_PATH" && echo "$MULTISHELL_WORKTREE_PATH""#
    )
  }
}
