import Foundation
import MultishellCore
import Testing

@testable import Multishell

/// A temp directory of fake executables, for detection on a fake PATH.
private func fakeBin(_ names: [String]) throws -> URL {
  let directory = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("multishell-bin-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  for name in names {
    let file = directory.appendingPathComponent(name)
    try "#!/bin/sh\nexit 0\n".write(to: file, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
  }
  return directory
}

@Suite
struct ShellDetectionTests {
  @Test func shellsComeFromTheSystemListAndThePathWithoutDuplicates() throws {
    let bin = try fakeBin(["fish", "zsh", "nu"])
    defer { try? FileManager.default.removeItem(at: bin) }
    let list = bin.appendingPathComponent("shells")
    try """
    # List of acceptable shells for chpass(1).

    /bin/zsh
    /bin/bash
    \(bin.appendingPathComponent("zsh").path)
    /no/such/shell
    """.write(to: list, atomically: true, encoding: .utf8)

    let detection = ShellDetection(path: bin.path, systemList: list, loginShell: "/bin/zsh")

    #expect(
      detection.installed == [
        "/bin/bash", bin.appendingPathComponent("fish").path,
        bin.appendingPathComponent("nu").path, "/bin/zsh", bin.appendingPathComponent("zsh").path,
      ], "sorted by name then path; the missing one dropped")
    #expect(detection.isInstalled("/bin/bash"))
    #expect(detection.isInstalled(ShellCatalogue.loginShellID))
    #expect(!detection.isInstalled("/opt/gone/fish"))
  }

  @Test func theDropdownLeadsWithTheLoginShellAndKeepsAStaleChoice() {
    let detection = ShellDetection(installed: ["/bin/bash", "/bin/zsh"], loginShell: "/bin/zsh")

    let plain = detection.options(selected: nil)
    #expect(plain.map(\.id) == ["login", "/bin/bash", "/bin/zsh"])
    #expect(plain[0].label == "Login shell (/bin/zsh)")
    #expect(plain[1].label == "bash  /bin/bash")

    let stale = detection.options(selected: "/opt/homebrew/bin/fish")
    #expect(stale.last?.id == "/opt/homebrew/bin/fish")
    #expect(stale.last?.label == "fish  /opt/homebrew/bin/fish (not installed)")
    #expect(stale.last?.isInstalled == false)
    #expect(detection.options(selected: "/bin/bash").count == 3, "an installed choice adds nothing")
  }

  @Test func aMissingSystemListIsNotAnError() {
    let detection = ShellDetection(
      path: "/nowhere", systemList: URL(fileURLWithPath: "/no/such/shells"), loginShell: "/bin/sh")
    #expect(detection.installed.isEmpty)
    #expect(detection.options(selected: nil).map(\.id) == ["login"])
  }
}

@Suite
struct EditorDetectionTests {
  @Test func editorsAreFoundByBundleIdOrByShimAndTerminalOnesByShimOnly() throws {
    let bin = try fakeBin(["code", "nvim"])
    defer { try? FileManager.default.removeItem(at: bin) }
    let apps = ["dev.zed.Zed": URL(fileURLWithPath: "/Applications/Zed.app")]

    let detection = EditorDetection(path: bin.path) { apps[$0] }

    #expect(Set(detection.found.keys) == ["vscode", "zed", "nvim"])
    #expect(detection.found["zed"]?.application?.path == "/Applications/Zed.app")
    #expect(detection.found["zed"]?.command == nil)
    #expect(detection.found["vscode"]?.application == nil, "found through its shim only")
    #expect(detection.found["vscode"]?.command?.path == bin.appendingPathComponent("code").path)
    #expect(detection.found["nvim"]?.command?.path == bin.appendingPathComponent("nvim").path)
    #expect(detection.isInstalled("custom") && !detection.isInstalled("cursor"))
  }

  @Test func theDropdownListsInstalledEditorsTheStaleChoiceAndCustom() {
    let detection = EditorDetection(found: [
      "zed": .init(application: URL(fileURLWithPath: "/Applications/Zed.app"), command: nil)
    ])
    #expect(detection.options(selected: nil).map(\.id) == ["none", "zed", "custom"])

    let stale = detection.options(selected: "vscode")
    #expect(stale.map(\.id) == ["none", "vscode", "zed", "custom"], "catalogue order")
    #expect(stale[1].label == "Visual Studio Code (not installed)")
    #expect(!stale[1].isInstalled)

    let unknown = detection.options(selected: "future-editor")
    #expect(unknown.map(\.id).contains("future-editor"), "a newer build's id still shows")
  }
}

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

@Suite
struct PendingProjectRemovalTests {
  @Test func theMessageCountsLiveTerminalsAndSaysTheDiskIsUntouched() {
    let none = PendingProjectRemoval.message(liveTerminals: 0)
    #expect(none.hasPrefix("Takes the project and its worktrees out of the sidebar."))
    #expect(!none.contains("terminal"))
    #expect(none.contains("Nothing on disk is touched"))
    #expect(PendingProjectRemoval.message(liveTerminals: 1).contains("1 open terminal will"))
    #expect(PendingProjectRemoval.message(liveTerminals: 3).contains("3 open terminals will"))
  }

  @Test func eachWindowPresentsOnlyItsOwnRequest() {
    let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
    let pending = PendingProjectRemoval(project: project, source: .settings)
    #expect(pending.id == project.id)
    #expect(pending.title == "Remove project demo?")
    #expect(pending.source == .settings && pending.source != .workspace)
  }
}
