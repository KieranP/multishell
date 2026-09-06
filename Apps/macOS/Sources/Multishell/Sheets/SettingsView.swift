import MultishellCore
import SwiftUI

/// App-wide preferences, under Multishell > Settings (Cmd+,).
/// Per-project settings live behind the cog on each sidebar row. Help sits
/// behind each row's (i); captions are kept for values computed live.
struct SettingsView: View {
  let model: AppModel

  var body: some View {
    TabView {
      GeneralSettingsTab(model: model)
        .tabItem { Label("General", systemImage: "gearshape") }
      WorktreeSettingsTab(model: model)
        .tabItem { Label("Worktrees", systemImage: "arrow.trianglehead.branch") }
      TerminalSettingsTab(model: model)
        .tabItem { Label("Terminal", systemImage: "terminal") }
      AgentSettingsTab(model: model)
        .tabItem { Label("Agents", systemImage: "sparkles") }
      AppearanceSettingsTab(model: model)
        .tabItem { Label("Appearance", systemImage: "paintpalette") }
    }
    .frame(width: 560, height: 480)
  }
}

private struct GeneralSettingsTab: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        EditorPicker(
          label: "Editor:",
          selection: Binding(
            get: { model.workspace.preferredEditorID ?? EditorCatalogue.noneID },
            set: { model.setPreferredEditor($0) }),
          detection: model.editorDetection,
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info:
            "What Open in Editor (⇧⌘O) in the worktree menu uses. Applications are found by bundle identifier, or by their command line shim on the login shell's PATH; a terminal editor opens as a new tab in the worktree."
        )
        if model.workspace.preferredEditorID == EditorCatalogue.customID {
          InfoRow(
            "Command:",
            info:
              "Run as a new tab in the worktree through your login shell, with {path} replaced by the worktree's quoted path, or the path appended if {path} is absent. A shell takes over when it exits."
          ) {
            TextField(
              "Command:",
              text: Binding(
                get: { model.workspace.customEditorCommand },
                set: { model.setCustomEditorCommand($0) }),
              prompt: Text("code-insiders {path}"))
          }
        }
      }

      Section {
        InfoRow(
          "Notifications:",
          info:
            "A system notification when a tab you are not looking at needs input, or finishes: an agent's turn, or a shell command that ran longer than ten seconds. Off by default; macOS asks for permission the first time one is posted."
        ) {
          Picker("Notifications:", selection: notifications) {
            ForEach(NotificationPreference.allCases, id: \.self) { Text($0.displayName).tag($0) }
          }
        }
      }

      Section {
        InfoRow(
          "State file:",
          info:
            "Projects, worktrees, tabs and these settings. Running shells are not saved; each tab gets a fresh one on relaunch."
        ) {
          Text(Paths.stateFile.path)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.head)
          IconButton.reveal { NSWorkspace.shared.activateFileViewerSelecting([Paths.stateFile]) }
            .controlSize(.small)
        }
      }
    }
    .formStyle(.grouped)
  }

  private var notifications: Binding<NotificationPreference> {
    Binding(get: { model.workspace.notifications }, set: { model.setNotifications($0) })
  }
}

/// What a tab runs and when one starts. The font is under Appearance with
/// the rest of the look.
private struct TerminalSettingsTab: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        InfoRow("Terminal engine:", info: engineInfo) {
          Picker("Terminal engine:", selection: engine) {
            ForEach(TerminalEngine.allCases, id: \.self) { Text($0.displayName).tag($0) }
          }
        }
        ShellPicker(
          label: "Default shell:",
          selection: Binding(
            get: { model.workspace.defaultShell ?? ShellCatalogue.loginShellID },
            set: { model.setDefaultShell($0) }),
          detection: model.shellDetection,
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info:
            "What new tabs run, and what project hooks run through. Terminals already running keep their shell. zsh and bash get the command-status hooks; another shell is launched plainly. Any project can override this. Refresh after installing one, or pick Custom path for one the list does not find."
        )
        if model.workspace.defaultShell == ShellCatalogue.customID {
          InfoRow(
            "Path:",
            info:
              "The shell's executable, for one that is neither in /etc/shells nor on the login shell's PATH. Run as a login shell like any other choice; a project override of Custom path means this same path."
          ) {
            TextField(
              "Path:",
              text: Binding(
                get: { model.workspace.customShellPath },
                set: { model.setCustomShellPath($0) }),
              prompt: Text("/opt/homebrew/bin/nu"))
          }
          if let problem = model.customShellPathProblem {
            SettingsCaption(problem)
          }
        }
        InfoToggle(
          "Open a terminal when a worktree is selected",
          info:
            "On, clicking a worktree with no tabs starts its first shell, or the agent where auto-start is on. Off, the worktree is shown empty and New Tab (⌘T) or the header's actions menu starts one.",
          isOn: Binding(
            get: { model.workspace.opensTerminalOnSelect },
            set: { model.setOpensTerminalOnSelect($0) }))
      }

    }
    .formStyle(.grouped)
  }

  private var engineInfo: String {
    model.workspace.terminalEngine == .swiftTerm
      ? "Used for every terminal opened from now on. Terminals already running keep the engine that started them. SwiftTerm has no shell integration and swallows the bell, so under it the state dots come from agent hooks alone."
      : "Used for every terminal opened from now on. Terminals already running keep the engine that started them."
  }

  private var engine: Binding<TerminalEngine> {
    Binding(get: { model.workspace.terminalEngine }, set: { model.setTerminalEngine($0) })
  }
}

private struct AppearanceSettingsTab: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        Picker("Theme:", selection: theme) {
          ForEach(model.themes) { Text($0.name).tag($0.id) }
        }
        InfoRow(
          "Theme files:",
          info:
            "Any .json in the folder appears in the list. The examples/ subfolder holds the built-ins to copy from; nothing in there is loaded."
        ) {
          Button("Open Folder") { model.revealThemesFolder() }
          IconButton.refresh(help: "Reload theme files") { model.reloadThemes() }
        }
        .controlSize(.small)
      }

      Section {
        InfoRow(
          "Terminal font:",
          info: "A font family name, as Font Book shows it. Blank uses the system monospace face."
        ) {
          TextField("Terminal font:", text: fontName, prompt: Text("System monospace"))
        }
        sizeRow(
          "Terminal size:", value: fontSize, current: model.workspace.appearance.fontSize,
          range: 9...24, info: "Terminal text. Applies to every open terminal.")
      }

      Section {
        sizeRow(
          "UI size:", value: uiFontSize, current: model.workspace.appearance.uiFontSize,
          range: 10...18, info: "Sidebar, tabs and header. Row heights follow it.")
      }
    }
    .formStyle(.grouped)
  }

  private var theme: Binding<Theme.ID> {
    Binding(get: { model.workspace.appearance.themeID }, set: { model.setTheme($0) })
  }

  private var fontName: Binding<String> {
    Binding(
      get: { model.workspace.appearance.fontName ?? "" },
      set: { name in
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        model.setFont(
          name: trimmed.isEmpty ? nil : trimmed, size: model.workspace.appearance.fontSize)
      }
    )
  }

  private var fontSize: Binding<Double> {
    Binding(
      get: { model.workspace.appearance.fontSize },
      set: { model.setFont(name: model.workspace.appearance.fontName, size: $0) }
    )
  }

  private var uiFontSize: Binding<Double> {
    Binding(get: { model.workspace.appearance.uiFontSize }, set: { model.setUIFontSize($0) })
  }

  private func sizeRow(
    _ label: String, value: Binding<Double>, current: Double, range: ClosedRange<Double>,
    info: String
  ) -> some View {
    InfoRow(label, info: info) {
      Slider(value: value, in: range, step: 1)
      Text("\(Int(current)) pt")
        .monospacedDigit()
        .frame(width: 40, alignment: .trailing)
    }
  }
}

private struct WorktreeSettingsTab: View {
  let model: AppModel

  var body: some View {
    let defaults = model.workspace.worktreeDefaults
    Form {
      Section {
        InfoRow(
          "Worktree path:",
          info:
            "Where each project's worktrees are created. Absolute, or relative to the repository. {project} is the repository folder name, ~ is home. Default ../{project}-worktrees. Any project can override it."
        ) {
          TextField("Worktree path:", text: field(\.worktreeDirectory))
        }
      }

      Section {
        InfoRow(
          "Branch prefix:",
          info:
            "Prepended to branch names typed in the new-worktree sheet. An existing branch keeps its name. Any project can override it."
        ) {
          TextField("Branch prefix:", text: field(\.branchPrefix), prompt: Text("none"))
        }
        if !defaults.branchPrefix.isEmpty {
          SettingsCaption("Typing tabs creates \(defaults.qualifiedBranch("tabs")).")
        }
      }

      Section {
        InfoToggle(
          "Ask before removing a worktree",
          info:
            "The confirmation also warns about uncommitted changes and open terminals in that worktree. Off is for people who remove worktrees all day; a removal then still asks about the branch unless the toggle below settles it.",
          isOn: Binding(
            get: { model.workspace.confirmsWorktreeRemoval },
            set: { model.setConfirmsWorktreeRemoval($0) }))
        InfoToggle(
          "Always delete the branch with its worktree",
          info:
            "Runs git branch -d after git worktree remove, once the post-delete hook has run. Off, removing a worktree asks whether the branch goes too. A branch with commits nothing else has is refused and offered again with the forced form.",
          isOn: Binding(
            get: { model.workspace.deletesBranchWithWorktree },
            set: { model.setDeletesBranchWithWorktree($0) }))
      }
    }
    .formStyle(.grouped)
  }

  private func field(_ keyPath: WritableKeyPath<WorktreeSettings, String>) -> Binding<String> {
    Binding(
      get: { model.workspace.worktreeDefaults[keyPath: keyPath] },
      set: { value in
        var defaults = model.workspace.worktreeDefaults
        defaults[keyPath: keyPath] = value
        model.setWorktreeDefaults(defaults)
      }
    )
  }
}

/// A value computed from the settings and shown live: a resolved path, an
/// example branch name. Help text goes behind an `InfoButton` instead.
struct SettingsCaption: View {
  let text: String

  init(_ text: String) { self.text = text }

  var body: some View {
    Text(text)
      .font(.system(size: 11))
      .foregroundStyle(.tertiary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

/// The dropdown both settings windows use for the shell: the login shell,
/// the installed ones, the stored value marked when it is not installed,
/// Custom path, and a Refresh.
struct ShellPicker: View {
  let label: String
  @Binding var selection: String
  let detection: ShellDetection
  let refresh: () -> Void
  let info: String
  /// Greys the control while an override is off; the (i) stays readable.
  var isEnabled = true

  var body: some View {
    InfoRow(label, info: info) {
      Picker(label, selection: $selection) {
        ForEach(detection.options(selected: selection)) { option in
          Text(option.label).tag(option.id)
        }
      }
      .disabled(!isEnabled)
      IconButton.refresh(action: refresh).controlSize(.small).disabled(!isEnabled)
    }
  }
}

/// The editor dropdown: None, installed editors, the stored value marked
/// when it is not installed, Custom, and a Refresh.
struct EditorPicker: View {
  let label: String
  @Binding var selection: String
  let detection: EditorDetection
  let refresh: () -> Void
  let info: String
  /// Greys the control while an override is off; the (i) stays readable.
  var isEnabled = true

  var body: some View {
    InfoRow(label, info: info) {
      Picker(label, selection: $selection) {
        ForEach(detection.options(selected: selection)) { option in
          Text(option.label).tag(option.id)
        }
      }
      .disabled(!isEnabled)
      IconButton.refresh(action: refresh).controlSize(.small).disabled(!isEnabled)
    }
  }
}
