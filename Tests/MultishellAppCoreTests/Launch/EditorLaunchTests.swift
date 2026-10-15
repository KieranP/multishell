import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct EditorLaunchTests {
  private let directory = URL(fileURLWithPath: "/Users/me/Work/repo trees/feat")

  private func action(
    _ id: String,
    found: EditorDetection.Found? = nil,
    custom: String = "",
    file: URL? = nil,
  ) -> EditorLaunch.Action? {
    EditorLaunch.action(
      editorID: id,
      found: found,
      customTemplate: custom,
      target: file.map(EditorTarget.file) ?? .worktree(directory),
      shell: .loginZsh,
      handOver: "exec /bin/zsh -l",
    )
  }

  @Test func anApplicationIsPreferredOverItsShimAndTheShimRunsInTheBackground() {
    let app = URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
    let shim = URL(fileURLWithPath: "/opt/homebrew/bin/code")
    #expect(
      action("vscode", found: .init(application: app, executable: shim)) == .openApplication(app)
    )
    #expect(
      action("vscode", found: .init(application: nil, executable: shim))
        == .runInBackground("/opt/homebrew/bin/code '/Users/me/Work/repo trees/feat'")
    )
    #expect(action("vscode", found: nil) == nil, "in the catalogue, not installed")
    #expect(action("no-such-editor") == nil)
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/tcsh")))
  func anEditorShimGetsAWorktreePathWithABangUnderInteractiveTcsh() async throws {
    let tcsh = "/bin/tcsh"
    let home = try Scratch.directory("editor-shim")
    defer { Scratch.remove(home) }
    let worktree = URL(fileURLWithPath: "/code/a!b")
    let shim = URL(fileURLWithPath: "/bin/echo")
    guard
      case .runInBackground(let line) = EditorLaunch.action(
        editorID: "vscode",
        found: .init(application: nil, executable: shim),
        customTemplate: "",
        target: .worktree(worktree),
        shell: .loginZsh,
        handOver: "exit",
      )
    else {
      Issue.record("the shim runs in the background")
      return
    }
    let text = try await Detached.output(
      of: tcsh,
      ["-f", "-i", "-c", line],
      environment: Scratch.bareShellEnvironment(home: home),
    )

    #expect(text == worktree.path + "\n")
  }

  @Test func aTerminalEditorIsATabRunningItInTheWorktreeWithAShellAfter() {
    let nvim = URL(fileURLWithPath: "/opt/homebrew/bin/nvim")
    #expect(
      action("nvim", found: .init(application: nil, executable: nvim))
        == .openTab(
          title: "Neovim",
          command: [
            "/bin/zsh", "-l", "-i", "-c",
            LeadingPathStatement.line(for: .loginZsh)
              + "/opt/homebrew/bin/nvim .; exec /bin/zsh -l",
          ],
        )
    )
    #expect(action("nvim", found: .init(application: nil, executable: nil)) == nil)
  }

  @Test func theCustomTemplateBecomesATabNamedForItsCommand() {
    #expect(
      action("custom", custom: "code-insiders {path}")
        == .openTab(
          title: "code-insiders",
          command: [
            "/usr/bin/env", "MULTISHELL_WORKTREE_PATH=/Users/me/Work/repo trees/feat",
            "/bin/zsh", "-l", "-i", "-c",
            LeadingPathStatement.line(for: .loginZsh)
              + #"code-insiders "$MULTISHELL_WORKTREE_PATH"; exec /bin/zsh -l"#,
          ],
        )
    )
    #expect(openTabTitle(action("custom", custom: "/usr/local/bin/micro")) == "micro")
    #expect(action("custom", custom: "   ") == nil, "nothing typed")
  }

  @Test func aFileIsHandedToTheEditorInPlaceOfTheWorktree() {
    let file = directory.appendingPathComponent("run.py")
    let nvim = URL(fileURLWithPath: "/opt/homebrew/bin/nvim")
    let shim = URL(fileURLWithPath: "/opt/homebrew/bin/code")
    #expect(
      action("nvim", found: .init(application: nil, executable: nvim), file: file)
        == .openTab(
          title: "Neovim",
          command: [
            "/bin/zsh", "-l", "-i", "-c",
            LeadingPathStatement.line(for: .loginZsh)
              + "/opt/homebrew/bin/nvim '/Users/me/Work/repo trees/feat/run.py'; exec /bin/zsh -l",
          ],
        )
    )
    #expect(
      action("vscode", found: .init(application: nil, executable: shim), file: file)
        == .runInBackground("/opt/homebrew/bin/code '/Users/me/Work/repo trees/feat/run.py'")
    )
  }

  private func openTabTitle(_ action: EditorLaunch.Action?) -> String? {
    if case .openTab(let title, _) = action { return title }
    return nil
  }
}
