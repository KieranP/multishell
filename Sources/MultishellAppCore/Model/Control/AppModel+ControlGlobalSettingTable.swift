import Foundation
import MultishellCore

extension AppModel {
  /// Named as `state.json` names them, a nested one with a dot.
  var globalSettings: [ControlSetting] {
    appearanceSettings + agentSettings + worktreeSettings + filesSettings + terminalSettings
      + editorSettings
      + NotificationPreference.notifiableStates.map(notificationSetting)
  }

  private var appearanceSettings: [ControlSetting] {
    [
      .text(
        "themeID",
        { self.workspace.appearance.themeID },
        accepts: { id in self.themes.contains { $0.id == id } },
        setTheme,
      ),
      .optionalText(
        "fontName",
        { self.workspace.appearance.terminalFontName },
        accepts: platform.hasFontFamily,
        { name in
          self.setTerminalFont(name: name, size: self.workspace.appearance.terminalFontSize)
        },
      ),
      .number(
        "fontSize",
        { self.workspace.appearance.terminalFontSize },
        in: Appearance.terminalFontSizes,
        setTerminalFontSize,
      ),
      .optionalText(
        "uiFontName",
        { self.workspace.appearance.uiFontName },
        accepts: platform.hasFontFamily,
        setUIFontName,
      ),
      .number(
        "uiFontSize",
        { self.workspace.appearance.uiFontSize },
        in: Appearance.uiFontSizes,
        setUIFontSize,
      ),
      .optionalText(
        "fileFontName",
        { self.workspace.appearance.fileFontName },
        accepts: platform.hasFontFamily,
        { name in self.setFileFont(name: name, size: self.workspace.appearance.fileFontSize) },
      ),
      .number(
        "fileFontSize",
        { self.workspace.appearance.fileFontSize },
        in: Appearance.fileFontSizes,
        setFileFontSize,
      ),
    ]
  }

  private var agentSettings: [ControlSetting] {
    let known = Set(AgentCatalogue.startableIDs)
    let flagSettings = known.sorted().map { id in
      ControlSetting.text(
        "agentFlags.\(id)",
        { self.workspace.agentFlags[id] ?? "" },
        { flags in self.setAgentFlags(flags, for: id) },
      )
    }
    return [
      .optionalText(
        "preferredAgentID",
        { self.workspace.preferredAgentID },
        accepts: known.contains,
        setPreferredAgent,
      ),
      .text("customAgentCommand", { self.workspace.customAgentCommand }, setCustomAgentCommand),
      .flag("autoStartAgent", { self.workspace.autoStartsAgent }, setAutoStartsAgent),
      .flag(
        "autoStartAgentOnCreate",
        { self.workspace.autoStartsAgentOnCreate },
        setAutoStartsAgentOnCreate,
      ),
    ] + flagSettings
  }

  private var worktreeSettings: [ControlSetting] {
    [
      worktreeDefault("worktreeDirectory", \.worktreeDirectory),
      worktreeDefault("branchPrefix", \.branchPrefix),
      .choice("worktreeSortOrder", { self.workspace.worktreeSortOrder }, setWorktreeSortOrder),
      .flag(
        "showsActiveWorktreesFirst",
        { self.workspace.showsActiveWorktreesFirst },
        setShowsActiveWorktreesFirst,
      ),
      .flag(
        "confirmsWorktreeRemoval",
        { self.workspace.confirmsWorktreeRemoval },
        setConfirmsWorktreeRemoval,
      ),
      .flag(
        "deletesBranchWithWorktree",
        { self.workspace.deletesBranchWithWorktree },
        setDeletesBranchWithWorktree,
      ),
      .flag(
        "trashesRemovedWorktrees",
        { self.workspace.trashesRemovedWorktrees },
        setTrashesRemovedWorktrees,
      ),
      .count(
        "hookTimeoutSeconds",
        { self.workspace.projectHookTimeoutSeconds },
        setProjectHookTimeoutSeconds,
      ),
      .choice("gitStatusIndicator", { self.workspace.gitStatusIndicator }, setGitStatusIndicator),
      .choice("diffAlgorithm", { self.workspace.diffAlgorithm }, setDiffAlgorithm),
    ]
  }

  private var filesSettings: [ControlSetting] {
    [
      .choice("fileTabLayout", { self.workspace.fileTabLayout }, setFileTabLayout),
      .choice("filesPanelMode", { self.workspace.filesPanelMode }, setFilesPanelMode),
    ]
  }

  private var terminalSettings: [ControlSetting] {
    [
      .flag(
        "opensTerminalOnSelect",
        { self.workspace.opensTerminalOnSelect },
        setOpensTerminalOnSelect,
      ),
      .flag(
        "opensTerminalOnCreate",
        { self.workspace.opensTerminalOnCreate },
        setOpensTerminalOnCreate,
      ),
      .optionalText(
        "defaultShell",
        { self.workspace.preferredShellID },
        accepts: isShellChoice,
        setPreferredShell,
      ),
      .text("customShellPath", { self.workspace.customShellPath }, setCustomShellPath),
    ]
  }

  private var editorSettings: [ControlSetting] {
    [
      .optionalText(
        "preferredEditorID",
        { self.workspace.preferredEditorID },
        accepts: { id in
          [EditorCatalogue.noneID, EditorCatalogue.customID].contains(id)
            || EditorCatalogue.editor(id) != nil
        },
        setPreferredEditor,
      ),
      .text("customEditorCommand", { self.workspace.customEditorCommand }, setCustomEditorCommand),
    ]
  }

  /// A shell the picker could hold: an executable named by its whole path, as
  /// the picker stores one, or the login or custom entry.
  private func isShellChoice(_ id: String) -> Bool {
    [ShellChoice.loginShellID, ShellChoice.customID].contains(id)
      || (id.hasPrefix("/") && FileManager.default.isExecutableFile(atPath: id))
  }

  /// `notifications.attention`, `.error` and `.done`, as the state file has them.
  private func notificationSetting(_ state: SessionState) -> ControlSetting {
    .flag(
      "notifications.\(state.rawValue)",
      { self.workspace.notificationPreference[state] },
      { enabled in
        var preference = self.workspace.notificationPreference
        preference[state] = enabled
        self.setNotificationPreference(preference)
      },
    )
  }

  private func worktreeDefault(
    _ name: String,
    _ field: WritableKeyPath<WorktreeSettings, String>,
  ) -> ControlSetting {
    .text(
      "worktreeDefaults.\(name)",
      { self.workspace.worktreeDefaults[keyPath: field] },
      { value in
        var defaults = self.workspace.worktreeDefaults
        defaults[keyPath: field] = value
        self.setWorktreeDefaults(defaults)
      },
    )
  }
}
