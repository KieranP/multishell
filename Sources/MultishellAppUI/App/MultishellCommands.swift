import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

struct MultishellCommands: Commands {
  let model: AppModel

  // Only the find items carry `.disabled`: Commands are not re-evaluated
  // reliably, so every action is also a no-op when it does not apply.
  var body: some Commands {
    aboutItem
    newItems
    pasteboardItems
    undoItems
    findMenu
    closeItems
    agentBoardItem
    terminalMenu
  }

  private var aboutItem: some Commands {
    CommandGroup(replacing: .appInfo) {
      Button(t("menu.about")) { AboutPanel.show() }
    }
  }

  private var newItems: some Commands {
    CommandGroup(replacing: .newItem) {
      Button(t("menu.new-tab")) { model.newTab() }
        .keyboardShortcut(AppShortcuts.newTab)
      Button(t("menu.new-shell-tab")) { model.newShellTab() }
        .keyboardShortcut(AppShortcuts.newShellTab)
      Button(t("menu.new-agent-tab")) { model.newAgentTab() }
        .keyboardShortcut(AppShortcuts.newAgentTab)
      Button(t("menu.new-worktree")) { model.requestNewWorktree() }
        .keyboardShortcut(AppShortcuts.newWorktree)
      Button(t("menu.add-project")) { Task { await model.chooseProject() } }
        .keyboardShortcut(AppShortcuts.addProject)
      Button(t("action.open-in-editor")) { model.openWorktreeInViewInEditor() }
        .keyboardShortcut(AppShortcuts.openInEditor)
    }
  }

  // SwiftUI's stock Edit items decide enablement on its update cycle, which
  // lags the responder chain. These send the selectors and stay enabled.
  private var pasteboardItems: some Commands {
    CommandGroup(replacing: .pasteboard) {
      Button(t("menu.cut")) { NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil) }
        .keyboardShortcut(AppShortcuts.cut)
      Button(t("action.copy")) { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }
        .keyboardShortcut(AppShortcuts.copy)
      Button(t("menu.paste")) { NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) }
        .keyboardShortcut(AppShortcuts.paste)
      Button(t("menu.select-all")) {
        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
      }
      .keyboardShortcut(AppShortcuts.selectAll)
    }
  }

  // The focused responder's own manager, not the key window's: a field
  // editor keeps one the window never sees, and asking covers both.
  private var undoItems: some Commands {
    CommandGroup(replacing: .undoRedo) {
      Button(t("menu.undo")) {
        guard let manager = Self.focusedUndoManager, manager.canUndo else { return }
        manager.undo()
      }
      .keyboardShortcut(AppShortcuts.undo)
      Button(t("menu.redo")) {
        guard let manager = Self.focusedUndoManager, manager.canRedo else { return }
        manager.redo()
      }
      .keyboardShortcut(AppShortcuts.redo)
    }
  }

  // Spelling, Substitutions and Speech have no meaning in a terminal, and
  // are the same lazily-validated kind as above. Find is the engine's.
  private var findMenu: some Commands {
    CommandGroup(replacing: .textEditing) {
      Menu(t("menu.find")) {
        Button(t("menu.find-item")) { model.showFind() }
          .keyboardShortcut(AppShortcuts.find)
          .disabled(!model.findIsAvailable)
        Button(t("menu.find-next")) { model.findNext() }
          .keyboardShortcut(AppShortcuts.findNext)
          .disabled(!model.findIsOpenInView)
        Button(t("menu.find-previous")) { model.findPrevious() }
          .keyboardShortcut(AppShortcuts.findPrevious)
          .disabled(!model.findIsOpenInView)
        Divider()
        Button(t("menu.close-find")) { model.closeFind() }
          .keyboardShortcut(AppShortcuts.closeFind)
          .disabled(!model.findIsOpenInView)
      }
    }
  }

  private var closeItems: some Commands {
    CommandGroup(replacing: .saveItem) {
      Button(t("close.pane-button")) { model.closeActivePane() }
        .keyboardShortcut(AppShortcuts.closePane)
      Button(t("close.tab-button")) { model.closeActiveTab() }
        .keyboardShortcut(AppShortcuts.closeTab)
    }
  }

  // Into the standard View menu, a `CommandMenu` of our own sitting beside
  // AppKit's rather than in it. The board is a place to go, not an action.
  private var agentBoardItem: some Commands {
    CommandGroup(after: .toolbar) {
      Button(t("label.agents")) { model.toggleAgentBoard() }
        .keyboardShortcut(AppShortcuts.toggleAgentBoard)
    }
  }

  private var terminalMenu: some Commands {
    CommandMenu(t("menu.terminal")) {
      Button(t("menu.split-right")) { model.splitActivePane(.horizontal) }
        .keyboardShortcut(AppShortcuts.splitRight)
      Button(t("menu.split-down")) { model.splitActivePane(.vertical) }
        .keyboardShortcut(AppShortcuts.splitDown)
      Divider()
      // Beside the splits, which is the layout it is a step out from: a
      // split divides a tab, this divides the worktree.
      Button(t("menu.move-tab-to-new-group")) { model.moveActiveTabToNewGroup() }
        .keyboardShortcut(AppShortcuts.moveTabToNewGroup)
      Button(t("menu.focus-next-group")) { model.focusNextGroup() }
        .keyboardShortcut(AppShortcuts.nextGroup)
      Button(t("menu.focus-previous-group")) { model.focusPreviousGroup() }
        .keyboardShortcut(AppShortcuts.previousGroup)
      Divider()
      Button(t("menu.next-tab")) { model.activateNextTab() }
        .keyboardShortcut(AppShortcuts.nextTab)
      Button(t("menu.previous-tab")) { model.activatePreviousTab() }
        .keyboardShortcut(AppShortcuts.previousTab)
      Divider()
      Picker(
        t("menu.theme"), selection: model.setting(\.appearance.themeID, write: model.setTheme)
      ) {
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
