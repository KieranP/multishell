import MultishellCore

/// The Shortcuts page's steps: recording a row's keys, saying why they were
/// refused, and asking before taking keys another command holds.
extension AppModel {
  /// The row being changed, if that is what the page is doing.
  var shortcutEditing: ShortcutEditing? {
    get {
      guard case .row(let editing) = shortcutsPageEdit else { return nil }
      return editing
    }
    set { shortcutsPageEdit = newValue.map(ShortcutsPageEdit.row) }
  }

  public var isAskingToRestoreShortcuts: Bool {
    shortcutsPageEdit == .restoringDefaults
  }

  /// The step a row shows, `nil` for every row but the one being changed.
  public func shortcutEditingStep(for command: ShortcutCommand) -> ShortcutEditing.Step? {
    shortcutEditing?.command == command ? shortcutEditing?.step : nil
  }

  public func startRecordingShortcut(for command: ShortcutCommand) {
    shortcutEditing = ShortcutEditing(command: command, step: .recording(nil))
  }

  /// Set where allowed, which ends the edit; otherwise the next step.
  public func takeRecordedShortcut(_ keys: KeyCombination, for command: ShortcutCommand) {
    switch setShortcut(keys, for: command) {
    case .allowed: shortcutEditing = nil

    case .refused(let refusal):
      shortcutEditing = ShortcutEditing(command: command, step: .recording(refusal))

    case .taken(let holder):
      shortcutEditing = ShortcutEditing(
        command: command,
        step: .confirming(keys, takenFrom: holder),
      )
    }
  }

  /// Delete while recording: no keys, the menu item staying.
  public func clearRecordedShortcut(for command: ShortcutCommand) {
    setShortcut(nil, for: command)
    shortcutEditing = nil
  }

  /// The reset arrow, judged as a set is: done, or a question where another
  /// command now holds the default.
  public func resetShortcut(_ command: ShortcutCommand) {
    let keys = command.defaultCombination
    guard case .taken(let holder) = setShortcut(keys, for: command) else { return }
    shortcutEditing = ShortcutEditing(
      command: command,
      step: .confirming(keys, takenFrom: holder),
    )
  }

  /// Replace, leaving the command that held the keys with none.
  public func replaceAskedShortcut() {
    guard let editing = shortcutEditing, case .confirming(let keys, _) = editing.step else {
      return
    }
    replaceShortcut(keys, for: editing.command)
    shortcutEditing = nil
  }

  public func askToRestoreShortcuts() {
    shortcutsPageEdit = .restoringDefaults
  }

  public func endShortcutsPageEdit() {
    shortcutsPageEdit = nil
  }
}
