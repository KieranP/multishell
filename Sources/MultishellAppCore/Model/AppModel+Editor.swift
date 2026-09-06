import Foundation
import MultishellCore
import MultishellProcess

// MARK: - Preferred editor and the worktree actions

extension AppModel {
  public func setPreferredEditor(_ id: String?) {
    store.setPreferredEditor(id == EditorCatalogue.noneID ? nil : id)
  }

  public func setCustomEditorCommand(_ command: String) {
    store.setCustomEditorCommand(command)
  }

  public func editorDisplayName(_ id: String) -> String {
    EditorCatalogue.displayName(id)
  }

  /// Open in Editor (Cmd+Shift+O) on the selected worktree.
  public func openSelectedWorktreeInEditor() {
    guard let worktree = workspace.selectedWorktree else { return }
    openInEditor(worktree)
  }

  /// An application takes the directory; a terminal editor, or the custom
  /// command, becomes a tab in the worktree.
  public func openInEditor(_ worktree: Worktree) {
    guard let editorID = workspace.effectiveEditorID else {
      presentedError = .noEditorChosen
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
      Task { [weak self] in
        do {
          try await self?.platform.open(worktree.path, withApplication: application)
        } catch {
          self?.report(error)
        }
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
