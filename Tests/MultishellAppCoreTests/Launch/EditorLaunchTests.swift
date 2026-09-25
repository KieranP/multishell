import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct EditorLaunchTests {
  private let zsh = ShellInvocation(
    executable: URL(fileURLWithPath: "/bin/zsh"), arguments: ["-l", "-i", "-c"])
  private let directory = URL(fileURLWithPath: "/Users/me/Work/repo trees/feat")

  private func action(
    _ id: String, found: EditorDetection.Found? = nil, custom: String = ""
  ) -> EditorLaunch.Action? {
    EditorLaunch.action(
      editorID: id, found: found, customTemplate: custom, directory: directory, shell: zsh,
      exec: "exec /bin/zsh -l")
  }

  @Test func anApplicationIsPreferredOverItsShimAndTheShimRunsInTheBackground() {
    let app = URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
    let shim = URL(fileURLWithPath: "/opt/homebrew/bin/code")
    #expect(
      action("vscode", found: .init(application: app, command: shim)) == .openApplication(app))
    #expect(
      action("vscode", found: .init(application: nil, command: shim))
        == .runInBackground("/opt/homebrew/bin/code '/Users/me/Work/repo trees/feat'"))
    #expect(action("vscode", found: nil) == nil, "in the catalogue, not installed")
    #expect(action("no-such-editor") == nil)
  }

  @Test func anEditorShimGetsAWorktreePathWithABangUnderInteractiveTcsh() async throws {
    let tcsh = "/bin/tcsh"
    guard FileManager.default.isExecutableFile(atPath: tcsh) else { return }
    let home = try Scratch.directory("editor-shim")
    defer { Scratch.remove(home) }
    let worktree = URL(fileURLWithPath: "/code/a!b")
    let shim = URL(fileURLWithPath: "/bin/echo")
    guard
      case .runInBackground(let line) = EditorLaunch.action(
        editorID: "vscode", found: .init(application: nil, command: shim), customTemplate: "",
        directory: worktree, shell: zsh, exec: "exit")
    else {
      Issue.record("the shim runs in the background")
      return
    }
    let text = try await Detached.output(
      of: tcsh, ["-f", "-i", "-c", line],
      environment: ["PATH": "/usr/bin:/bin", "HISTFILE": "", "HOME": home.path])

    #expect(text == worktree.path + "\n")
  }

  @Test func aTerminalEditorIsATabRunningItInTheWorktreeWithAShellAfter() {
    let nvim = URL(fileURLWithPath: "/opt/homebrew/bin/nvim")
    #expect(
      action("nvim", found: .init(application: nil, command: nvim))
        == .openTab(
          title: "Neovim",
          command: ["/bin/zsh", "-l", "-i", "-c", "/opt/homebrew/bin/nvim .; exec /bin/zsh -l"]))
    #expect(action("nvim", found: .init(application: nil, command: nil)) == nil)
  }

  @Test func theCustomTemplateBecomesATabNamedForItsCommand() {
    #expect(
      action("custom", custom: "code-insiders {path}")
        == .openTab(
          title: "code-insiders",
          command: [
            "/usr/bin/env", "MULTISHELL_WORKTREE_PATH=/Users/me/Work/repo trees/feat",
            "/bin/zsh", "-l", "-i", "-c",
            #"code-insiders "$MULTISHELL_WORKTREE_PATH"; exec /bin/zsh -l"#,
          ]))
    #expect(action("custom", custom: "/usr/local/bin/micro")?.self.title == "micro")
    #expect(action("custom", custom: "   ") == nil, "nothing typed")
  }
}

extension EditorLaunch.Action {
  fileprivate var title: String? {
    if case .openTab(let title, _) = self { return title }
    return nil
  }
}
