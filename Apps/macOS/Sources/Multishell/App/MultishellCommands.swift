import AppKit
import MultishellCore
import SwiftUI

struct MultishellCommands: Commands {
  let model: AppModel

  var body: some Commands {
    // No `.disabled` here: Commands are not re-evaluated reliably when the
    // model changes, so a disabled item can stay disabled. Each action is
    // a no-op when it does not apply.
    CommandGroup(replacing: .newItem) {
      Button("New Tab") { model.newTab() }
        .keyboardShortcut(AppShortcuts.newTab)
      Button("New Shell Tab") { model.newShellTab() }
        .keyboardShortcut(AppShortcuts.newShellTab)
      Button("New Agent Tab") { model.newAgentTab() }
        .keyboardShortcut(AppShortcuts.newAgentTab)
      Button("New Worktree…") { model.requestNewWorktree() }
        .keyboardShortcut(AppShortcuts.newWorktree)
      Button("Add Project…") { Task { await model.chooseProject() } }
        .keyboardShortcut(AppShortcuts.addProject)
      Button("Open in Editor") { model.openSelectedWorktreeInEditor() }
        .keyboardShortcut(AppShortcuts.openInEditor)
    }

    // SwiftUI's stock Edit items decide their own enablement on its update
    // cycle, which can lag the responder chain by seconds. These send the
    // standard selectors to the first responder, the way AppKit menus do, and
    // stay enabled; a terminal with nothing selected simply ignores copy:.
    CommandGroup(replacing: .pasteboard) {
      Button("Cut") { NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil) }
        .keyboardShortcut(AppShortcuts.cut)
      Button("Copy") { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }
        .keyboardShortcut(AppShortcuts.copy)
      Button("Paste") { NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) }
        .keyboardShortcut(AppShortcuts.paste)
      Button("Select All") { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
        .keyboardShortcut(AppShortcuts.selectAll)
    }

    // The focused responder's own manager, not the key window's: a text field
    // edits in the window's field editor, which keeps a manager of its own
    // that the window's never sees. A `TextEditor`'s manager is the window's,
    // so asking the responder covers both. A terminal surface has none and
    // the walk up ends at the window's, which holds nothing only while no
    // `TextEditor` shares that window; one beside a pane would undo into it
    // from a prompt. `NSApp.sendAction` is no use: `undo:` and `redo:`, what
    // the stock items send, are undeclared, and `NSWindow` answers them from
    // its own manager.
    CommandGroup(replacing: .undoRedo) {
      Button("Undo") {
        guard let manager = Self.focusedUndoManager, manager.canUndo else { return }
        manager.undo()
      }
      .keyboardShortcut(AppShortcuts.undo)
      Button("Redo") {
        guard let manager = Self.focusedUndoManager, manager.canRedo else { return }
        manager.redo()
      }
      .keyboardShortcut(AppShortcuts.redo)
    }

    // Find, Spelling, Substitutions, Speech: text-editing items with no
    // meaning in a terminal, and the same lazily-validated kind as above.
    CommandGroup(replacing: .textEditing) {}

    CommandGroup(replacing: .saveItem) {
      Button("Close Pane") { model.closeActivePane() }
        .keyboardShortcut(AppShortcuts.closePane)
      Button("Close Tab") { model.closeActiveTab() }
        .keyboardShortcut(AppShortcuts.closeTab)
    }

    // Into the standard View menu rather than a `CommandMenu("View")` of our
    // own, which would sit beside the one AppKit adds for the toolbar rather
    // than in it. The board is a place to go, not something done to the
    // focused pane, so it does not belong in Terminal.
    CommandGroup(after: .toolbar) {
      Button("Agents") { model.toggleAgentBoard() }
        .keyboardShortcut(AppShortcuts.showAgents)
    }

    CommandMenu("Terminal") {
      Button("Split Right") { model.splitActivePane(.horizontal) }
        .keyboardShortcut(AppShortcuts.splitRight)
      Button("Split Down") { model.splitActivePane(.vertical) }
        .keyboardShortcut(AppShortcuts.splitDown)
      Divider()
      // Beside the splits, which is the layout it is a step out from: a
      // split divides a tab, this divides the worktree.
      Button("Move Tab to New Group") { model.moveActiveTabToNewGroup() }
        .keyboardShortcut(AppShortcuts.moveTabToNewGroup)
      Button("Focus Next Group") { model.focusNextGroup() }
        .keyboardShortcut(AppShortcuts.nextGroup)
      Button("Focus Previous Group") { model.focusPreviousGroup() }
        .keyboardShortcut(AppShortcuts.previousGroup)
      Divider()
      Button("Next Tab") { model.selectNextTab() }
        .keyboardShortcut(AppShortcuts.nextTab)
      Button("Previous Tab") { model.selectPreviousTab() }
        .keyboardShortcut(AppShortcuts.previousTab)
      Divider()
      Picker("Theme", selection: model.setting(\.appearance.themeID, write: model.setTheme)) {
        ForEach(model.themes) { theme in
          Text(theme.name).tag(theme.id)
        }
      }
    }
  }

  private static var focusedUndoManager: UndoManager? {
    NSApp.keyWindow?.firstResponder?.undoManager
  }
}
