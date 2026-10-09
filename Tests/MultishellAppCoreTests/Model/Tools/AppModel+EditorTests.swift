import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelEditorTests {
  /// Nothing that acts on the tab in front of the user acts at all while the
  /// board covers it, and nothing starts a shell where a removal is running.
  @Test func openInEditorLeavesTheBoardAndRefusesABusyWorktree() {
    let harness = Harness()
    harness.model.setPreferredEditor(EditorCatalogue.customID)
    harness.model.setCustomEditorCommand("my-editor {path}")
    harness.model.showAgentBoard()
    #expect(harness.model.showsAgentBoard)

    harness.model.openInEditor(harness.main)

    #expect(
      !harness.model.showsAgentBoard,
      "a tab opened behind the board nobody can see or close",
    )
    #expect(harness.model.workspace.activeTab(in: harness.main.id) != nil)

    let busy = Harness()
    busy.model.setPreferredEditor(EditorCatalogue.customID)
    busy.model.setCustomEditorCommand("my-editor {path}")
    busy.model.worktreeOperations.begin(.preDeleteHook, on: busy.main.id)
    busy.model.presentedError = nil

    busy.model.openInEditor(busy.main)

    #expect(busy.model.workspace.tabs.isEmpty, "its directory is about to be trashed")
  }

  @Test func anEditorsShimRunsUnderTheProjectsShell() async throws {
    let harness = Harness()
    let shells = harness.root.appendingPathComponent("shells", isDirectory: true)
    try FileManager.default.createDirectory(at: shells, withIntermediateDirectories: true)
    let ran = harness.root.appendingPathComponent("shell-ran")
    let shell = try Scratch.script(
      "printf '%s' \"$MULTISHELL_SCRIPT\" > '\(ran.path)'",
      at: shells.appendingPathComponent("bash"),
    )
    let code = try Scratch.script("exit 0", at: shells.appendingPathComponent("code"))
    harness.model.editorDetection = EditorDetection(
      found: ["vscode": .init(application: nil, executable: code)])
    harness.model.setPreferredEditor("vscode")
    harness.model.setSettings(ProjectSettings(preferredShellID: shell.path), for: harness.project)

    harness.model.openInEditor(harness.main)

    try await waitUntil { FileManager.default.fileExists(atPath: ran.path) }
    #expect(try String(contentsOf: ran, encoding: .utf8).contains(code.path))
  }

  @Test func anInstalledApplicationIsHandedTheWorktreesDirectory() async throws {
    let harness = Harness()
    let vscode = URL(fileURLWithPath: "/Applications/Visual Studio Code.app", isDirectory: true)
    harness.platform.applications["com.microsoft.VSCode"] = vscode
    await harness.model.refreshLoginEnvironment()
    harness.model.setPreferredEditor("vscode")

    harness.model.openInEditor(harness.main)

    try await waitUntil { !harness.platform.opened.isEmpty }
    #expect(harness.platform.opened.map { $0.directory } == [harness.main.path])
    #expect(harness.platform.opened.map { $0.application } == [vscode])
    #expect(harness.model.workspace.tabs.isEmpty, "the application opens it, not a tab")
  }

  @Test func openInEditorFromTheMenuOverTheBoardOpensNothing() {
    let harness = Harness()
    harness.model.setPreferredEditor(EditorCatalogue.customID)
    harness.model.setCustomEditorCommand("my-editor {path}")
    harness.model.select(harness.main)
    let opened = harness.engine.opened.count
    harness.model.showAgentBoard()

    harness.model.openWorktreeInViewInEditor()

    #expect(harness.engine.opened.count == opened, "no worktree is on screen to open")
    #expect(harness.model.showsAgentBoard)
  }

  @Test func openInEditorNeedsAnEditorAndACustomOneBecomesATab() throws {
    let harness = Harness()
    harness.model.presentedError = nil
    harness.model.openInEditor(harness.main)
    #expect(harness.model.presentedError?.title == "No editor chosen")
    #expect(harness.model.workspace.tabs.isEmpty)

    harness.model.presentedError = nil
    harness.model.setPreferredEditor(EditorCatalogue.customID)
    harness.model.openInEditor(harness.main)
    #expect(harness.model.presentedError?.title == "No editor command", "nothing typed yet")

    harness.model.presentedError = nil
    harness.model.setCustomEditorCommand("my-editor {path}")
    harness.model.openInEditor(harness.main)
    #expect(harness.model.presentedError == nil)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    #expect(harness.model.workspace.title(of: tab) == "my-editor")
    #expect(
      harness.model.workspace.selectedWorktreeID == harness.main.id,
      "the tab is brought on screen",
    )
    #expect(harness.model.liveTerminalCount == 1)
    #expect(harness.engine.opened.last?.command?.last?.hasPrefix("my-editor ") == true)
    #expect(
      harness.engine.opened.last?.command?.contains(
        "MULTISHELL_WORKTREE_PATH=\(harness.main.path.path)"
      )
        == true
    )

    harness.model.setPreferredEditor("vscode")
    harness.model.openInEditor(harness.main)
    #expect(harness.model.presentedError?.title == "Visual Studio Code is not installed")
  }

  @Test func theCustomCommandFieldShowsOnlyForTheCustomEditor() {
    let harness = Harness()
    #expect(!harness.model.usesCustomEditor)

    harness.model.setPreferredEditor(EditorCatalogue.customID)
    #expect(harness.model.usesCustomEditor)

    harness.model.setPreferredEditor("vscode")
    #expect(!harness.model.usesCustomEditor)
  }
}
