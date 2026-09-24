import Foundation
import MultishellCore
import MultishellProcess

extension AppModel {
  public func setPreferredEditor(_ id: String?) {
    store.setPreferredEditor(id == EditorCatalogue.noneID ? nil : id)
  }

  public func setCustomEditorCommand(_ command: String) {
    store.setCustomEditorCommand(command)
  }

  func editorDisplayName(_ id: String) -> String {
    EditorCatalogue.displayName(id)
  }

  /// Open in Editor (Cmd+Shift+O) on the worktree on screen, which over the
  /// board is none, no row drawing as selected there.
  public func openSelectedWorktreeInEditor() {
    guard let worktree = worktreeInView else { return }
    openInEditor(worktree)
  }

  /// An application takes the directory; a terminal editor, or the custom
  /// command, becomes a tab in the worktree.
  public func openInEditor(_ worktree: Worktree) {
    guard let editorID = workspace.effectiveEditorID else {
      presentedError = .noEditorChosen
      return
    }
    guard readyForShell(worktree), let shell = ShellCommand.shell else { return }
    let action = EditorLaunch.action(
      editorID: editorID,
      found: editorDetection.found[editorID],
      customTemplate: workspace.customEditorCommand,
      directory: worktree.path,
      shell: shell,
      exec: ShellLaunch.execCommandLine(forShell: shellPath(forWorktree: worktree.id)))
    switch action {
    case .openApplication(let application):
      Task { [weak self] in
        do {
          try await self?.platform.open(worktree.path, withApplication: application)
        } catch {
          self?.report(error)
        }
      }
    case .runInBackground(let line):
      let shellPath = workspace.project(worktree.projectID).flatMap(workspace.defaultShell)
      Task { [weak self] in
        do {
          try await ShellCommand().launch(line, in: worktree.path, shellPath: shellPath)
        } catch {
          self?.report(error)
        }
      }
    case .openTab(let title, let command):
      // Or the editor runs in a pane the board covers, which Cmd+W cannot
      // reach either: nothing acts on the tab in front while it is up.
      leaveAgentBoard()
      store.openTab(in: worktree.id, title: title, command: command)
      store.selectWorktree(worktree.id)
      warmWorktrees.insert(worktree.id)
      reconcileSessions(takingFocus: true)
    case nil:
      presentedError =
        editorID == EditorCatalogue.customID
        ? .noEditorCommand : .editorNotInstalled(editorDisplayName(editorID))
    }
  }

  public func revealInFileBrowser(_ url: URL) {
    platform.revealInFileBrowser(url)
  }

  public func copyToClipboard(_ text: String) {
    platform.copyToClipboard(text)
  }
}
