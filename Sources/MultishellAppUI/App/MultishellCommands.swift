import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

struct MultishellCommands: Commands {
  private static var focusedUndoManager: UndoManager? {
    NSApp.keyWindow?.firstResponder?.undoManager
  }

  let model: AppModel

  // Only the find items carry `.disabled`: a disabled item gives its key to the
  // pane, and Commands are not re-evaluated reliably. Each action is a no-op.
  var body: some Commands {
    aboutItem
    newItems
    printItems
    pasteboardItems
    undoItems
    findMenu
    closeItems
    viewItems
    terminalMenu
  }

  private var aboutItem: some Commands {
    CommandGroup(replacing: .appInfo) {
      Button(t("menu.about")) { AboutPanel.show() }
    }
  }

  private var newItems: some Commands {
    CommandGroup(replacing: .newItem) {
      Button(ShortcutCommand.newProject.menuTitle) { Task { await model.addProjectFromPicker() } }
        .keyboardShortcut(.newProject, in: model)
      Button(ShortcutCommand.newWorktree.menuTitle) { model.requestNewWorktree() }
        .keyboardShortcut(.newWorktree, in: model)
      Divider()
      Button(ShortcutCommand.newTab.menuTitle) { model.newTab() }
        .keyboardShortcut(.newTab, in: model)
      Button(ShortcutCommand.newShellTab.menuTitle) { model.newShellTab() }
        .keyboardShortcut(.newShellTab, in: model)
      Button(ShortcutCommand.newAgentTab.menuTitle) { model.newAgentTab() }
        .keyboardShortcut(.newAgentTab, in: model)
      Divider()
      Button(ShortcutCommand.openInEditor.menuTitle) { model.openWorktreeInViewInEditor() }
        .keyboardShortcut(.openInEditor, in: model)
    }
  }

  // Print and Page Setup would take Cmd+P and Shift+Cmd+P, the quick
  // switcher's default keys, and nothing here prints.
  private var printItems: some Commands {
    CommandGroup(replacing: .printItem) {}
  }

  // SwiftUI's stock Edit items decide enablement on its update cycle, which
  // lags the responder chain. These send the selectors and stay enabled.
  private var pasteboardItems: some Commands {
    CommandGroup(replacing: .pasteboard) {
      Button(ShortcutCommand.cut.menuTitle) {
        NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
      }
      .keyboardShortcut(.cut, in: model)
      Button(ShortcutCommand.copy.menuTitle) {
        NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
      }
      .keyboardShortcut(.copy, in: model)
      Button(ShortcutCommand.paste.menuTitle) {
        NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
      }
      .keyboardShortcut(.paste, in: model)
      Button(ShortcutCommand.selectAll.menuTitle) {
        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
      }
      .keyboardShortcut(.selectAll, in: model)
    }
  }

  // The focused responder's own manager, not the key window's: a field
  // editor keeps one the window never sees, and asking covers both.
  private var undoItems: some Commands {
    CommandGroup(replacing: .undoRedo) {
      Button(ShortcutCommand.undo.menuTitle) {
        guard let manager = Self.focusedUndoManager, manager.canUndo else { return }
        manager.undo()
      }
      .keyboardShortcut(.undo, in: model)
      Button(ShortcutCommand.redo.menuTitle) {
        guard let manager = Self.focusedUndoManager, manager.canRedo else { return }
        manager.redo()
      }
      .keyboardShortcut(.redo, in: model)
    }
  }

  // Spelling, Substitutions and Speech have no meaning in a terminal, and
  // are the same lazily-validated kind as above. Find is the app's own.
  private var findMenu: some Commands {
    CommandGroup(replacing: .textEditing) {
      Menu(t("menu.find")) {
        Button(ShortcutCommand.find.menuTitle) { model.showFind() }
          .keyboardShortcut(.find, in: model)
          .disabled(!model.findIsAvailable)
        Button(ShortcutCommand.findNext.menuTitle) { model.findNext() }
          .keyboardShortcut(.findNext, in: model)
          .disabled(!model.findIsOpenInView)
        Button(ShortcutCommand.findPrevious.menuTitle) { model.findPrevious() }
          .keyboardShortcut(.findPrevious, in: model)
          .disabled(!model.findIsOpenInView)
        Divider()
        Button(ShortcutCommand.closeFind.menuTitle) { model.closeFind() }
          .keyboardShortcut(.closeFind, in: model)
          .disabled(!model.findIsOpenInView)
      }
    }
  }

  private var closeItems: some Commands {
    CommandGroup(replacing: .saveItem) {
      Button(ShortcutCommand.closePane.menuTitle) { model.closeActivePane() }
        .keyboardShortcut(.closePane, in: model)
      Button(ShortcutCommand.closeTab.menuTitle) { model.closeActiveTab() }
        .keyboardShortcut(.closeTab, in: model)
    }
  }

  // Into the standard View menu, not a `CommandMenu`, which would sit beside
  // AppKit's: the board and the debug tools change what is shown, not act.
  private var viewItems: some Commands {
    CommandGroup(after: .toolbar) {
      Button(ShortcutCommand.toggleAgentBoard.menuTitle) { model.toggleAgentBoard() }
        .keyboardShortcut(.toggleAgentBoard, in: model)
      Divider()
      Toggle(ShortcutCommand.filesPane.menuTitle, isOn: model.filesPanelBinding(on: .files))
        .keyboardShortcut(.filesPane, in: model)
      Toggle(ShortcutCommand.changesPane.menuTitle, isOn: model.filesPanelBinding(on: .changes))
        .keyboardShortcut(.changesPane, in: model)
      Toggle(ShortcutCommand.reviewPane.menuTitle, isOn: model.filesPanelBinding(on: .review))
        .keyboardShortcut(.reviewPane, in: model)
      Toggle(
        t("menu.show-hidden-files"),
        isOn: model.settingBinding(\.showsIgnoredFiles, write: model.setShowsIgnoredFiles),
      )
      Divider()
      Button(ShortcutCommand.quickSwitcher.menuTitle) { model.toggleQuickSwitcher(.all) }
        .keyboardShortcut(.quickSwitcher, in: model)
      Button(ShortcutCommand.quickSwitcherCommands.menuTitle) {
        model.toggleQuickSwitcher(.commands)
      }
      .keyboardShortcut(.quickSwitcherCommands, in: model)
      Button(ShortcutCommand.filterProjects.menuTitle) { model.filterProjects() }
        .keyboardShortcut(.filterProjects, in: model)
      Divider()
      ThemePicker(title: t("menu.theme"), model: model)
      Divider()
      Toggle(t("menu.enable-debug-tools"), isOn: model.debugToolsEnabledBinding)
    }
  }

  private var terminalMenu: some Commands {
    CommandMenu(t("menu.terminal")) {
      Button(ShortcutCommand.splitRight.menuTitle) { model.splitActivePane(.horizontal) }
        .keyboardShortcut(.splitRight, in: model)
      Button(ShortcutCommand.splitDown.menuTitle) { model.splitActivePane(.vertical) }
        .keyboardShortcut(.splitDown, in: model)
      Divider()
      Button(ShortcutCommand.focusNextPane.menuTitle) { model.focusNextPane() }
        .keyboardShortcut(.focusNextPane, in: model)
      Button(ShortcutCommand.focusPreviousPane.menuTitle) { model.focusPreviousPane() }
        .keyboardShortcut(.focusPreviousPane, in: model)
      Divider()
      Button(ShortcutCommand.nextTab.menuTitle) { model.activateNextTab() }
        .keyboardShortcut(.nextTab, in: model)
      Button(ShortcutCommand.previousTab.menuTitle) { model.activatePreviousTab() }
        .keyboardShortcut(.previousTab, in: model)
      Divider()
      Button(ShortcutCommand.moveTabToNewGroup.menuTitle) { model.moveActiveTabToNewGroup() }
        .keyboardShortcut(.moveTabToNewGroup, in: model)
      Button(ShortcutCommand.focusNextGroup.menuTitle) { model.focusNextGroup() }
        .keyboardShortcut(.focusNextGroup, in: model)
      Button(ShortcutCommand.focusPreviousGroup.menuTitle) { model.focusPreviousGroup() }
        .keyboardShortcut(.focusPreviousGroup, in: model)
      actionItems
    }
  }

  /// The selected worktree's actions, which the quick switcher lists as
  /// commands from here, each with the keys its Actions page gave it.
  @ViewBuilder private var actionItems: some View {
    let groups = model.actionMenuBarGroups
    if !groups.isEmpty {
      Divider()
      Menu(t("menu.actions")) {
        ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
          if index > 0 { Divider() }
          ForEach(group) { item in
            Button(item.name) { model.runActionInView(named: item.name) }
              .keyboardShortcut(item.keys?.keyboardShortcut(isChanged: true))
          }
        }
      }
    }
  }
}
