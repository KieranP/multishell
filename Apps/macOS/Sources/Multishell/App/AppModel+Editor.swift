import AppKit
import MultishellCore
import MultishellProcess

// MARK: - Preferred editor and the worktree actions

extension AppModel {
  func setPreferredEditor(_ id: String?) {
    store.setPreferredEditor(id == EditorCatalogue.noneID ? nil : id)
  }

  func setCustomEditorCommand(_ command: String) {
    store.setCustomEditorCommand(command)
  }

  func editorDisplayName(_ id: String) -> String {
    if id == EditorCatalogue.customID { return "Custom command" }
    return EditorCatalogue.editor(id)?.name ?? id
  }

  /// Open in Editor (Cmd+Shift+O) on the selected worktree.
  func openSelectedWorktreeInEditor() {
    guard let worktree = workspace.selectedWorktree else { return }
    openInEditor(worktree)
  }

  /// An application takes the directory; a terminal editor, or the custom
  /// command, becomes a tab in the worktree.
  func openInEditor(_ worktree: Worktree) {
    guard let editorID = workspace.effectiveEditorID else {
      presentedError = PresentedError(
        title: "No editor chosen",
        message: "Pick a preferred editor in Settings > General.")
      return
    }
    guard directoryExists(of: worktree), let shell = ShellCommand.shell else { return }
    let action = EditorLaunch.action(
      editorID: editorID,
      found: editorDetection.found[editorID],
      customTemplate: workspace.customEditorCommand,
      directory: worktree.path,
      shell: shell,
      exec: ShellLaunch.execCommandLine(forShell: shellPath(forWorktree: worktree.id)))
    switch action {
    case .openApplication(let application):
      NSWorkspace.shared.open(
        [worktree.path], withApplicationAt: application, configuration: .init()
      ) { [weak self] _, error in
        guard let error else { return }
        Task { @MainActor in self?.report(error) }
      }
    case .runInBackground(let line):
      Task { [weak self] in
        do {
          _ = try await ShellCommand().run(line, in: worktree.path)
        } catch {
          self?.report(error)
        }
      }
    case .openTab(let title, let command):
      store.openTab(in: worktree.id, title: title, command: command)
      store.selectWorktree(worktree.id)
      warmWorktrees.insert(worktree.id)
      sync()
    case nil:
      let name = editorDisplayName(editorID)
      presentedError = PresentedError(
        title: editorID == EditorCatalogue.customID
          ? "No editor command" : "\(name) is not installed",
        message: editorID == EditorCatalogue.customID
          ? "Type the command in Settings > General, with {path} for the worktree."
          : "Install \(name), or choose another editor in Settings > General, then use Refresh.")
    }
  }

  func revealInFinder(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  func copyToPasteboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }
}
