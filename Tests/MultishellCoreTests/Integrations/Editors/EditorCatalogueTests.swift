import Foundation
import Testing

@testable import MultishellCore

@Suite
struct EditorCatalogueTests {
  @Test func noneAndEmptyMeanNoEditor() {
    #expect(EditorCatalogue.effectiveID(nil) == nil)
    #expect(EditorCatalogue.effectiveID("") == nil)
    #expect(EditorCatalogue.effectiveID(EditorCatalogue.noneID) == nil)
    #expect(EditorCatalogue.effectiveID("vscode") == "vscode")
    #expect(EditorCatalogue.editor("vscode")?.bundleIdentifier == "com.microsoft.VSCode")
    #expect(EditorCatalogue.editor("nvim")?.kind == .terminal)
  }

  @Test func idsAreUnique() {
    let ids = EditorCatalogue.editors.map(\.id)
    #expect(Set(ids).count == ids.count)
    #expect(!ids.contains(EditorCatalogue.noneID) && !ids.contains(EditorCatalogue.customID))
  }

  @Test func theCustomTemplateReadsThePathFromTheEnvironmentWhereThePlaceholderIs() {
    let path = URL(fileURLWithPath: "/Users/me/My Work/repo")
    let environment = ["MULTISHELL_WORKTREE_PATH": "/Users/me/My Work/repo"]
    #expect(
      EditorCatalogue.customCommandLine("code-insiders {path}", path: path)
        == ShellLine(text: #"code-insiders "$MULTISHELL_WORKTREE_PATH""#, environment: environment))
    #expect(
      EditorCatalogue.customCommandLine("  micro  ", path: path)
        == ShellLine(text: #"micro "$MULTISHELL_WORKTREE_PATH""#, environment: environment),
      "no placeholder: the path is appended")
    #expect(EditorCatalogue.customCommandLine("  ", path: path) == nil)
    #expect(
      EditorCatalogue.customCommandLine("open -a X {path} && echo {path}", path: path)?.text
        == #"open -a X "$MULTISHELL_WORKTREE_PATH" && echo "$MULTISHELL_WORKTREE_PATH""#)
  }
}
