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
        .keyboardShortcut("t")
      Button("New Shell Tab") { model.newShellTab() }
        .keyboardShortcut("t", modifiers: [.command, .shift])
      Button("New Agent Tab") { model.newAgentTab() }
        .keyboardShortcut("t", modifiers: [.command, .option])
      Button("New Worktree…") { model.requestNewWorktree() }
        .keyboardShortcut("n")
      Button("Add Project…") { Task { await model.chooseProject() } }
        .keyboardShortcut("o")
      Button("Open in Editor") { model.openSelectedWorktreeInEditor() }
        .keyboardShortcut("o", modifiers: [.command, .shift])
    }

    // SwiftUI's stock Edit items decide their own enablement on its update
    // cycle, which can lag the responder chain by seconds. These send the
    // standard selectors to the first responder, the way AppKit menus do, and
    // stay enabled; a terminal with nothing selected simply ignores copy:.
    CommandGroup(replacing: .pasteboard) {
      Button("Cut") { NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil) }
        .keyboardShortcut("x")
      Button("Copy") { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }
        .keyboardShortcut("c")
      Button("Paste") { NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) }
        .keyboardShortcut("v")
      Button("Select All") { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
        .keyboardShortcut("a")
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
      .keyboardShortcut("z")
      Button("Redo") {
        guard let manager = Self.focusedUndoManager, manager.canRedo else { return }
        manager.redo()
      }
      .keyboardShortcut("z", modifiers: [.command, .shift])
    }

    // Find, Spelling, Substitutions, Speech: text-editing items with no
    // meaning in a terminal, and the same lazily-validated kind as above.
    CommandGroup(replacing: .textEditing) {}

    CommandGroup(replacing: .saveItem) {
      Button("Close Pane") { model.closeActivePane() }
        .keyboardShortcut("w")
      Button("Close Tab") { model.closeActiveTab() }
        .keyboardShortcut("w", modifiers: [.command, .shift])
    }

    CommandMenu("Terminal") {
      Button("Split Right") { model.splitActivePane(.horizontal) }
        .keyboardShortcut("d")
      Button("Split Down") { model.splitActivePane(.vertical) }
        .keyboardShortcut("d", modifiers: [.command, .shift])
      Divider()
      Button("Next Tab") { model.selectNextTab() }
        .keyboardShortcut(.tab, modifiers: .control)
      Button("Previous Tab") { model.selectPreviousTab() }
        .keyboardShortcut(.tab, modifiers: [.control, .shift])
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
