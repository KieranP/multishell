import MultishellCore
import SwiftUI

/// Per-project settings, as a window that matches Multishell > Settings:
/// icon tabs in the toolbar, changes applied as they are made, closed with
/// the window's own close button.
struct ProjectSettingsWindow: View {
  static let windowID = "project-settings"

  let model: AppModel
  let projectID: Project.ID

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    if let project = model.workspace.project(projectID) {
      ToolbarTabs(tabs: [
        .init("General", symbol: "gearshape") { GeneralTab(model: model, project: project) },
        .init("Worktrees", symbol: "arrow.trianglehead.branch") {
          WorktreesTab(model: model, project: project)
        },
        .init("Hooks", symbol: "bolt.horizontal") { HooksTab(model: model, project: project) },
        .init("Terminal", symbol: "terminal") { TerminalTab(model: model, project: project) },
        .init("Agents", symbol: "sparkles") { AgentTab(model: model, project: project) },
      ])
      .frame(width: 560, height: 480)
      .navigationTitle("\(project.name) Settings")
      // This window is its own scene, so a removal asked for here has to
      // be confirmed here; the workspace window's dialog would be behind it.
      .projectRemovalDialog(model: model, source: .settings)
    } else {
      // The project was removed while this window was open.
      Color.clear.frame(width: 1, height: 1).onAppear { dismiss() }
    }
  }
}

/// A binding into the project's settings that writes straight to the store.
@MainActor
private func setting<Value>(
  _ keyPath: WritableKeyPath<ProjectSettings, Value>, of project: Project, in model: AppModel
) -> Binding<Value> {
  Binding(
    get: {
      model.workspace.project(project.id)?.settings[keyPath: keyPath]
        ?? project.settings[keyPath: keyPath]
    },
    set: { value in
      var settings = model.workspace.project(project.id)?.settings ?? project.settings
      settings[keyPath: keyPath] = value
      model.updateSettings(settings, for: project)
    }
  )
}

private struct GeneralTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let worktrees = model.workspace.worktrees(of: project.id)
    Form {
      Section {
        LabeledContent("Repository:") {
          HStack {
            Text(project.path.path)
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.head)
            Button("Reveal") { model.revealInFinder(project.path) }
              .controlSize(.small)
          }
        }
        LabeledContent("Worktrees:") {
          HStack {
            Text("\(worktrees.count) discovered")
            Button("Refresh") { Task { await model.refreshRequested(project) } }
              .controlSize(.small)
          }
        }
      }

      ProjectIconSection(model: model, project: project)

      Section {
        InfoToggle(
          "Ask before removing a worktree",
          info:
            "The confirmation also warns about uncommitted changes and open terminals in that worktree. Off is for people who remove worktrees all day.",
          isOn: setting(\.confirmsWorktreeRemoval, of: project, in: model))
      }

      Section {
        HStack(spacing: 8) {
          Button("Remove Project…", role: .destructive) {
            model.requestProjectRemoval(project, from: .settings)
          }
          InfoButton(
            "Takes the project out of the sidebar and closes its terminals, after asking. Nothing on disk is touched."
          )
        }
      }
    }
    .formStyle(.grouped)
  }
}

/// The project's shell override, following the global choice by default.
private struct TerminalTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let settings = model.workspace.project(project.id)?.settings ?? project.settings
    Form {
      Section {
        InfoToggle(
          "Override default shell",
          info:
            "New tabs in this project's worktrees run this shell instead of the global choice, and so do its hooks. Login shell here means $SHELL whatever the global says.",
          isOn: overridesShell)
        ShellPicker(
          label: "Shell:",
          selection: Binding(
            get: {
              settings.defaultShell ?? model.workspace.defaultShell ?? ShellCatalogue.loginShellID
            },
            set: { model.updateSettings(with(settings, shell: $0), for: project) }),
          detection: model.shellDetection,
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info:
            "The shells in /etc/shells and on the login shell's PATH. Refresh after installing one.",
          isEnabled: settings.defaultShell != nil
        )
      } footer: {
        if settings.defaultShell == nil {
          SettingsCaption(
            "Using the global value, \(model.shellDisplayName(model.workspace.defaultShell)).")
        }
      }
    }
    .formStyle(.grouped)
  }

  /// Turning the override on seeds it with the global value, or the login
  /// shell; turning it off returns to following the global.
  private var overridesShell: Binding<Bool> {
    let source = setting(\.defaultShell, of: project, in: model)
    let global = model.workspace.defaultShell ?? ShellCatalogue.loginShellID
    return Binding(
      get: { source.wrappedValue != nil },
      set: { on in source.wrappedValue = on ? global : nil }
    )
  }

  private func with(_ settings: ProjectSettings, shell: String) -> ProjectSettings {
    var updated = settings
    updated.defaultShell = shell
    return updated
  }
}

/// The glyph and tint the sidebar draws for the project. Two controls set
/// one glyph: a symbol from the curated list, or an emoji typed or pasted
/// from the character palette; whichever was set last wins.
private struct ProjectIconSection: View {
  let model: AppModel
  let project: Project

  private static let emojiTag = "emoji"
  private static let folderTag = "folder"

  var body: some View {
    let settings = model.workspace.project(project.id)?.settings ?? project.settings
    let kind = ProjectIcon.kind(of: settings.iconGlyph)
    Section("Icon") {
      InfoRow(
        "Symbol:",
        info:
          "Drawn in the sidebar, the header and the project picker in place of the folder. Whichever was set last wins: picking a symbol replaces an emoji, typing an emoji replaces the symbol."
      ) {
        Picker("Symbol:", selection: symbol(settings, kind: kind)) {
          Label("Folder", systemImage: "folder").tag(Self.folderTag)
          if case .emoji(let emoji) = kind {
            Text("\(emoji)  Emoji").tag(Self.emojiTag)
          }
          Divider()
          ForEach(ProjectIcon.symbols.filter { $0 != "folder" }, id: \.self) { name in
            Label(name, systemImage: name).tag(name)
          }
        }
        ProjectIconView(settings: settings, isMissing: false, theme: model.currentTheme, size: 14)
      }
      InfoRow(
        "Emoji:",
        info:
          "One character; ⌃⌘Space opens the palette. Emoji keep their own colours, so the tint does not apply."
      ) {
        TextField("Emoji:", text: emoji(settings, kind: kind), prompt: Text("Optional"))
          .frame(width: 60)
      }
      InfoRow(
        "Tint:",
        info:
          "One of the theme's sixteen colours, so a later theme change keeps the icon in step with the terminal. Applies to symbols and the folder."
      ) {
        HStack(spacing: 5) {
          swatch(nil, settings: settings, color: model.currentTheme.textSecondary)
          ForEach(0..<16, id: \.self) { slot in
            swatch(slot, settings: settings, color: model.currentTheme.ansiRGB[slot].color)
          }
        }
      }
    }
  }

  private func symbol(_ settings: ProjectSettings, kind: ProjectIcon.Kind) -> Binding<String> {
    Binding(
      get: {
        switch kind {
        case .folder: Self.folderTag
        case .emoji: Self.emojiTag
        case .symbol(let name): name
        }
      },
      set: { chosen in
        guard chosen != Self.emojiTag else { return }
        update(settings) { $0.iconGlyph = chosen == Self.folderTag ? nil : chosen }
      })
  }

  private func emoji(_ settings: ProjectSettings, kind: ProjectIcon.Kind) -> Binding<String> {
    Binding(
      get: {
        if case .emoji(let emoji) = kind { return emoji }
        return ""
      },
      set: { typed in
        switch ProjectIcon.kind(of: typed) {
        case .emoji(let emoji): update(settings) { $0.iconGlyph = emoji }
        case .folder, .symbol:
          // Cleared, or ASCII typed by mistake: back to the folder, unless a
          // symbol is what the glyph already is.
          if case .emoji = kind { update(settings) { $0.iconGlyph = nil } }
        }
      })
  }

  private func swatch(_ slot: Int?, settings: ProjectSettings, color: Color) -> some View {
    let selected = settings.iconTint == slot
    return Button {
      update(settings) { $0.iconTint = slot }
    } label: {
      ZStack {
        Circle().fill(color).frame(width: 14, height: 14)
        if slot == nil {
          Image(systemName: "xmark").font(.system(size: 7, weight: .bold)).foregroundStyle(.white)
        }
      }
      .overlay {
        if selected { Circle().strokeBorder(Color.primary, lineWidth: 1.5).padding(-2.5) }
      }
      .frame(width: 18, height: 18)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(slot.map { Self.slotNames[$0] } ?? "No tint")
  }

  private static let slotNames = [
    "Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White",
    "Bright black", "Bright red", "Bright green", "Bright yellow", "Bright blue",
    "Bright magenta", "Bright cyan", "Bright white",
  ]

  private func update(_ settings: ProjectSettings, _ change: (inout ProjectSettings) -> Void) {
    var updated = settings
    change(&updated)
    model.updateSettings(updated, for: project)
  }
}

private struct WorktreesTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let defaults = model.workspace.worktreeDefaults
    let settings = model.workspace.project(project.id)?.settings ?? project.settings
    let effective = settings.effective(defaults: defaults)

    Form {
      Section {
        InfoToggle(
          "Override worktree path",
          info:
            "Where this project's worktrees are created. {project} is the repository folder name, ~ is home. Relative paths start at the repository.",
          isOn: overrides(\.worktreeDirectory, default: defaults.worktreeDirectory))
        TextField("Path:", text: text(\.worktreeDirectory, fallback: defaults.worktreeDirectory))
          .disabled(settings.worktreeDirectory == nil)
        SettingsCaption("Resolves to \(effective.worktreeContainer(for: project).path)")
      }

      Section {
        InfoToggle(
          "Override branch prefix",
          info:
            "Prepended to branch names typed in the new-worktree sheet for this project. Turn the override on and leave it blank to use no prefix while the global has one.",
          isOn: overrides(\.branchPrefix, default: defaults.branchPrefix))
        TextField(
          "Prefix:", text: text(\.branchPrefix, fallback: defaults.branchPrefix),
          prompt: Text("none")
        )
        .disabled(settings.branchPrefix == nil)
        SettingsCaption(
          "Typing tabs creates \(effective.qualifiedBranch("tabs")) at \(effective.worktreePath(forBranch: effective.qualifiedBranch("tabs"), in: project).path)"
        )
      }
    }
    .formStyle(.grouped)
  }

  /// Turning an override on seeds it with the global value so the field is
  /// never blank; turning it off returns to following the global.
  private func overrides(
    _ keyPath: WritableKeyPath<ProjectSettings, String?>, default value: String
  )
    -> Binding<Bool>
  {
    let source = setting(keyPath, of: project, in: model)
    return Binding(
      get: { source.wrappedValue != nil },
      set: { on in source.wrappedValue = on ? (source.wrappedValue ?? value) : nil }
    )
  }

  /// Shows the global value while the override is off, so the disabled
  /// field reads as what is in effect rather than as empty.
  private func text(
    _ keyPath: WritableKeyPath<ProjectSettings, String?>, fallback: String
  ) -> Binding<String> {
    let source = setting(keyPath, of: project, in: model)
    return Binding(
      get: { source.wrappedValue ?? fallback },
      set: { source.wrappedValue = $0 }
    )
  }
}

/// The project's agent override, following the global choice by default.
private struct AgentTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let settings = model.workspace.project(project.id)?.settings ?? project.settings
    let global = model.workspace.preferredAgentID
    Form {
      Section {
        InfoToggle(
          "Override preferred agent",
          info:
            "New Agent Tab (⌥⌘T) in this project's worktrees starts this agent instead of the global one. None opts the project out. The custom command is the global one.",
          isOn: overrides(default: global))
        AgentPicker(
          label: "Agent:",
          selection: Binding(
            get: { settings.preferredAgentID ?? global ?? AgentCatalogue.noneID },
            set: { model.updateSettings(with(settings, agent: $0), for: project) }),
          detection: model.agentDetection,
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info: "Agents found on the login shell's PATH. Refresh after installing one.",
          isEnabled: settings.preferredAgentID != nil
        )
      } footer: {
        if settings.preferredAgentID == nil {
          SettingsCaption(
            "Using the global value, \(model.agentDisplayName(global ?? AgentCatalogue.noneID)).")
        }
      }

      Section {
        InfoToggle(
          "Override auto-start",
          info:
            "Whether New Tab and a worktree's first tab here start the agent, whatever the global says.",
          isOn: overridesAutoStart)
        Toggle(
          "Start the agent in new tabs",
          isOn: Binding(
            get: { settings.autoStartAgent ?? model.workspace.autoStartAgent },
            set: { model.updateSettings(with(settings, autoStart: $0), for: project) })
        )
        .disabled(settings.autoStartAgent == nil)
      } footer: {
        if settings.autoStartAgent == nil {
          SettingsCaption(
            "Using the global value: \(model.workspace.autoStartAgent ? "on" : "off").")
        }
      }
    }
    .formStyle(.grouped)
  }

  private func with(_ settings: ProjectSettings, autoStart: Bool) -> ProjectSettings {
    var updated = settings
    updated.autoStartAgent = autoStart
    return updated
  }

  /// Turning the override on seeds it with the global value.
  private var overridesAutoStart: Binding<Bool> {
    let source = setting(\.autoStartAgent, of: project, in: model)
    let global = model.workspace.autoStartAgent
    return Binding(
      get: { source.wrappedValue != nil },
      set: { on in source.wrappedValue = on ? global : nil }
    )
  }

  private func with(_ settings: ProjectSettings, agent: String) -> ProjectSettings {
    var updated = settings
    updated.preferredAgentID = agent
    return updated
  }

  /// Turning the override on seeds it with the global value, or None.
  private func overrides(default global: String?) -> Binding<Bool> {
    let source = setting(\.preferredAgentID, of: project, in: model)
    return Binding(
      get: { source.wrappedValue != nil },
      set: { on in source.wrappedValue = on ? (global ?? AgentCatalogue.noneID) : nil }
    )
  }
}

/// Four scripts, grouped by the operation they surround. Each is a small
/// monospaced editor, since a hook of any substance has more than one line.
private struct HooksTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    Form {
      Section("Create") {
        HookEditor(
          title: "Pre-create",
          info:
            "Runs in the repository before git worktree add, with MULTISHELL_WORKTREE_PATH set to the planned path. A non-zero exit stops the create; git is never asked.",
          placeholder: "test -n \"$TICKET\" || { echo 'set TICKET first' >&2; exit 1; }",
          text: setting(\.preCreateHook, of: project, in: model))
        HookEditor(
          title: "Post-create",
          info:
            "Runs in the new worktree after git worktree add. A failure is reported; the worktree stays.",
          placeholder: "npm install\ncp \"$MULTISHELL_PROJECT_PATH/.env\" .",
          text: setting(\.postCreateHook, of: project, in: model))
      }

      Section("Delete") {
        HookEditor(
          title: "Pre-delete",
          info:
            "Runs in the worktree before git worktree remove, after the confirmation. A non-zero exit stops the removal; the worktree stays.",
          placeholder: "test -z \"$(git log @{upstream}.. 2>/dev/null)\" || exit 1",
          text: setting(\.preDeleteHook, of: project, in: model))
        HookEditor(
          title: "Post-delete",
          info: "Runs in the repository after git worktree remove, once the directory is gone.",
          placeholder: "Optional shell script",
          text: setting(\.postDeleteHook, of: project, in: model))
      }

      Section {
        ForEach(Self.hookVariables, id: \.name) { variable in
          LabeledContent {
            Text(variable.meaning).foregroundStyle(.secondary)
          } label: {
            Text(variable.name).font(.system(size: 11, design: .monospaced))
          }
        }
      } header: {
        HStack(spacing: 6) {
          Text("Environment")
          InfoButton(
            "Each script runs through this project's shell (the Terminal tab; $SHELL unless chosen) as an interactive login shell, with these variables set, so nothing needs quoting. In sh, bash and zsh the first failing line stops the script and is the one reported; fish runs the whole script."
          )
        }
      }
    }
    .formStyle(.grouped)
  }

  private static let hookVariables: [(name: String, meaning: String)] = [
    ("MULTISHELL_PROJECT_PATH", "Repository root"),
    ("MULTISHELL_PROJECT_NAME", "Repository folder name"),
    ("MULTISHELL_WORKTREE_PATH", "The worktree created or removed"),
    ("MULTISHELL_BRANCH", "Its branch"),
  ]
}

private struct HookEditor: View {
  let title: String
  let info: String
  let placeholder: String
  @Binding var text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      InfoLabel(title, info: info)
      TextEditor(text: $text)
        .font(.system(size: 11, design: .monospaced))
        .scrollContentBackground(.hidden)
        .frame(minHeight: 48, maxHeight: 96)
        .padding(4)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 5))
        .overlay(alignment: .topLeading) {
          if text.isEmpty {
            Text(placeholder)
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(.tertiary)
              .padding(.horizontal, 9)
              .padding(.vertical, 4)
              .allowsHitTesting(false)
          }
        }
    }
    .padding(.vertical, 2)
  }
}
