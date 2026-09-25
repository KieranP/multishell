import MultishellCore
import MultishellProcess

extension AppModel {
  public func setPreferredEditor(_ id: String?) {
    store.setPreferredEditor(id == EditorCatalogue.noneID ? nil : id)
  }

  public func setCustomEditorCommand(_ command: String) {
    store.setCustomEditorCommand(command)
  }

  /// Whether the editor picker is on the custom command, whose field shows.
  public var usesCustomEditor: Bool {
    workspace.preferredEditorID == EditorCatalogue.customID
  }

  /// Open in Editor (Cmd+Shift+O) on the worktree on screen, which over the
  /// board is none, no row drawing as selected there.
  public func openWorktreeInViewInEditor() {
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
    guard requireShellReady(worktree) else { return }
    let (shell, handOver) = TabCommand.loginShell(
      handingOverTo: shellPath(forWorktree: worktree.id))
    let action = EditorLaunch.action(
      editorID: editorID,
      found: editorDetection.found[editorID],
      customTemplate: workspace.customEditorCommand,
      directory: worktree.path,
      shell: shell,
      handOver: handOver)
    switch action {
    case .openApplication(let application):
      Task { [weak self] in
        do {
          try await self?.platform.open(worktree.path, withApplication: application)
        } catch {
          self?.present(error)
        }
      }
    case .runInBackground(let line):
      let shellPath = shellPath(for: worktree)
      Task { [weak self] in
        do {
          try await ShellCommand.launch(line, in: worktree.path, shellPath: shellPath)
        } catch {
          self?.present(error)
        }
      }
    case .openTab(let title, let command):
      // Or the editor runs in a pane the board covers, which Cmd+W cannot
      // reach either: nothing acts on the tab in front while it is up.
      hideAgentBoard(markingInViewSeen: false)
      store.openTab(in: worktree.id, title: title, command: command)
      store.selectWorktree(worktree.id)
      warmWorktrees.insert(worktree.id)
      reconcileSessions(takingFocus: true)
    case nil:
      presentedError =
        editorID == EditorCatalogue.customID
        ? .noEditorCommand : .editorNotInstalled(EditorCatalogue.displayName(editorID))
    }
  }
}
