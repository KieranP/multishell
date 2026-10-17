import Foundation
import MultishellCore
import MultishellProcess

extension AppModel {
  /// Whether the editor picker is on the custom command, whose field shows.
  public var usesCustomEditor: Bool {
    workspace.preferredEditorID == EditorCatalogue.customID
  }

  public func setPreferredEditor(_ id: String?) {
    store.setPreferredEditor(id == EditorCatalogue.noneID ? nil : id)
  }

  public func setCustomEditorCommand(_ command: String) {
    store.setCustomEditorCommand(command)
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
    let shellPath = shellPath(for: worktree)
    let target = EditorTarget.worktree(worktree.path)
    runEditorAction(
      editorAction(target, editorID: editorID, shellPath: shellPath),
      opening: target,
      editorID: editorID,
      in: worktree,
      shellPath: shellPath,
    )
  }

  /// A link clicked in a pane named a text file; terminals.md says where it goes.
  func openInEditor(file: URL, clickedIn sessionID: TerminalSession.ID) {
    guard
      let tab = workspace.tab(owning: sessionID),
      let worktree = workspace.worktree(tab.worktreeID)
    else { return }
    openInEditor(file: file, in: worktree)
  }

  /// A file of `worktree` in the editor: from a clicked link, the Files panel
  /// or a file tab. A terminal editor opens its tab in that worktree.
  func openInEditor(file: URL, in worktree: Worktree) {
    guard let editorID = workspace.effectiveEditorID else {
      openInPlainTextEditor(file)
      return
    }
    let shellPath = shellPath(for: worktree)
    let target = EditorTarget.file(file)
    let action = editorAction(target, editorID: editorID, shellPath: shellPath)
    if action?.startsAShell == true {
      // A worktree being created or removed takes no new tab or shell.
      guard !isBusy(worktree.id) else {
        openInPlainTextEditor(file)
        return
      }
      guard requireDirectory(of: worktree) else { return }
    }
    runEditorAction(
      action,
      opening: target,
      editorID: editorID,
      in: worktree,
      shellPath: shellPath,
    )
  }

  private func editorAction(
    _ target: EditorTarget,
    editorID: String,
    shellPath: String,
  ) -> EditorLaunch.Action? {
    let (shell, handOver) = TabCommand.loginShell(handingOverTo: shellPath)
    return EditorLaunch.action(
      editorID: editorID,
      found: editorDetection.found[editorID],
      customTemplate: workspace.customEditorCommand,
      target: target,
      shell: shell,
      handOver: handOver,
    )
  }

  private func openInPlainTextEditor(_ file: URL) {
    if let editor = platform.plainTextEditorURL() { open(file, inApplication: editor) }
  }

  private func runEditorAction(
    _ action: EditorLaunch.Action?,
    opening target: EditorTarget,
    editorID: String,
    in worktree: Worktree,
    shellPath: String,
  ) {
    switch action {
    case .openApplication(let application):
      open(target.path, inApplication: application)

    case .runInBackground(let line):
      Task { [weak self] in
        do {
          try await ShellCommand.runUncaptured(line, in: worktree.path, shellPath: shellPath)
        } catch {
          self?.present(error)
        }
      }

    case .openTab(let title, let command):
      store.openTab(in: worktree.id, title: title, command: command)
      select(worktree, openingFirstTab: .never)

    case nil:
      presentedError =
        editorID == EditorCatalogue.customID
        ? .noEditorCommand : .editorNotInstalled(EditorCatalogue.displayName(editorID))
    }
  }

  private func open(_ item: URL, inApplication application: URL) {
    Task { [weak self] in
      do {
        try await self?.platform.open(item, withApplication: application)
      } catch {
        self?.present(error)
      }
    }
  }
}
