import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct EditorLaunchTests {
  private let zsh = (executable: URL(fileURLWithPath: "/bin/zsh"), arguments: ["-l", "-i", "-c"])
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
            "/bin/zsh", "-l", "-i", "-c",
            "code-insiders '/Users/me/Work/repo trees/feat'; exec /bin/zsh -l",
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
