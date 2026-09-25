import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelEditorTests {
  /// Nothing that acts on the tab in front of the user acts at all while the
  /// board covers it, and nothing starts a shell where a removal is running.
  @Test func openInEditorLeavesTheBoardAndRefusesABusyWorktree() throws {
    let h = Harness()
    h.model.setPreferredEditor(EditorCatalogue.customID)
    h.model.setCustomEditorCommand("my-editor {path}")
    h.model.showAgentBoard()
    #expect(h.model.showsAgentBoard)

    h.model.openInEditor(h.main)

    #expect(!h.model.showsAgentBoard, "a tab opened behind the board nobody can see or close")
    #expect(h.model.workspace.activeTab(in: h.main.id) != nil)

    let busy = Harness()
    busy.model.setPreferredEditor(EditorCatalogue.customID)
    busy.model.setCustomEditorCommand("my-editor {path}")
    busy.model.worktreeOperations.begin(.preDeleteHook, on: busy.main.id)
    busy.model.presentedError = nil

    busy.model.openInEditor(busy.main)

    #expect(busy.model.workspace.tabs.isEmpty, "its directory is about to be trashed")
  }

  @Test func anEditorsShimRunsUnderTheProjectsShell() async throws {
    let h = Harness()
    let shells = h.root.appendingPathComponent("shells", isDirectory: true)
    try FileManager.default.createDirectory(at: shells, withIntermediateDirectories: true)
    let ran = h.root.appendingPathComponent("shell-ran")
    let shell = try Scratch.script(
      "printf '%s' \"$MULTISHELL_SCRIPT\" > '\(ran.path)'",
      at: shells.appendingPathComponent("bash"))
    let code = try Scratch.script("exit 0", at: shells.appendingPathComponent("code"))
    h.model.editorDetection = EditorDetection(
      found: ["vscode": .init(application: nil, command: code)])
    h.model.setPreferredEditor("vscode")
    h.model.updateSettings(ProjectSettings(preferredShellID: shell.path), for: h.project)

    h.model.openInEditor(h.main)

    try await waitUntil { FileManager.default.fileExists(atPath: ran.path) }
    #expect(try String(contentsOf: ran, encoding: .utf8).contains(code.path))
  }

  @Test func openInEditorFromTheMenuOverTheBoardOpensNothing() {
    let h = Harness()
    h.model.setPreferredEditor(EditorCatalogue.customID)
    h.model.setCustomEditorCommand("my-editor {path}")
    h.model.select(h.main)
    let opened = h.engine.opened.count
    h.model.showAgentBoard()

    h.model.openWorktreeInViewInEditor()

    #expect(h.engine.opened.count == opened, "no worktree is on screen to open")
    #expect(h.model.showsAgentBoard)
  }

  @Test func openInEditorNeedsAnEditorAndACustomOneBecomesATab() throws {
    let h = Harness()
    h.model.presentedError = nil
    h.model.openInEditor(h.main)
    #expect(h.model.presentedError?.title == "No editor chosen")
    #expect(h.model.workspace.tabs.isEmpty)

    h.model.presentedError = nil
    h.model.setPreferredEditor(EditorCatalogue.customID)
    h.model.openInEditor(h.main)
    #expect(h.model.presentedError?.title == "No editor command", "nothing typed yet")

    h.model.presentedError = nil
    h.model.setCustomEditorCommand("my-editor {path}")
    h.model.openInEditor(h.main)
    #expect(h.model.presentedError == nil)
    let tab = try #require(h.model.workspace.activeTab(in: h.main.id))
    #expect(h.model.workspace.title(of: tab) == "my-editor")
    #expect(h.model.workspace.selectedWorktreeID == h.main.id, "the tab is brought on screen")
    #expect(h.model.liveTerminalCount == 1)
    #expect(h.engine.opened.last?.command?.last?.hasPrefix("my-editor ") == true)
    #expect(
      h.engine.opened.last?.command?.contains("MULTISHELL_WORKTREE_PATH=\(h.main.path.path)")
        == true)

    h.model.setPreferredEditor("vscode")
    h.model.openInEditor(h.main)
    #expect(h.model.presentedError?.title == "Visual Studio Code is not installed")
  }

  @Test func theCustomCommandFieldShowsOnlyForTheCustomEditor() {
    let h = Harness()
    #expect(!h.model.usesCustomEditor)

    h.model.setPreferredEditor(EditorCatalogue.customID)
    #expect(h.model.usesCustomEditor)

    h.model.setPreferredEditor("vscode")
    #expect(!h.model.usesCustomEditor)
  }
}
