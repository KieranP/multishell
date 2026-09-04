import MultishellCore
import SwiftUI

/// App-wide preferences, under Multishell > Settings (Cmd+,).
/// Per-project settings live behind the cog on each sidebar row.
struct SettingsView: View {
  let model: AppModel

  var body: some View {
    TabView {
      GeneralSettingsTab(model: model)
        .tabItem { Label("General", systemImage: "gearshape") }
      AppearanceSettingsTab(model: model)
        .tabItem { Label("Appearance", systemImage: "paintpalette") }
      WorktreeSettingsTab(model: model)
        .tabItem { Label("Worktrees", systemImage: "arrow.trianglehead.branch") }
    }
    .frame(width: 540, height: 360)
  }
}

private struct GeneralSettingsTab: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        Picker("Terminal engine:", selection: engine) {
          ForEach(TerminalEngine.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        SettingsCaption(
          "Used for every terminal opened from now on. Terminals already running keep the engine that started them."
        )
      }

      Section {
        LabeledContent("State file:") {
          HStack {
            Text(Paths.stateFile.path)
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.head)
            Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([Paths.stateFile]) }
              .controlSize(.small)
          }
        }
        SettingsCaption(
          "Projects, worktrees, tabs and these settings. Running shells are not saved; each tab gets a fresh one on relaunch."
        )
      }
    }
    .formStyle(.grouped)
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
        LabeledContent("Theme files:") {
          HStack {
            Button("Open Folder") { model.revealThemesFolder() }
            Button("Reload") { model.reloadThemes() }
          }
          .controlSize(.small)
        }
        SettingsCaption(
          "Any .json in the folder appears in the list. The examples/ subfolder holds the built-ins to copy from; nothing in there is loaded."
        )
      }

      Section {
        TextField("Terminal font:", text: fontName, prompt: Text("System monospace"))
        sizeRow(
          "Terminal size:", value: fontSize, current: model.workspace.appearance.fontSize,
          range: 9...24)
      }

      Section {
        sizeRow(
          "UI size:", value: uiFontSize, current: model.workspace.appearance.uiFontSize,
          range: 10...18)
        SettingsCaption("Sidebar, tabs and header. Row heights follow it.")
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
    _ label: String, value: Binding<Double>, current: Double, range: ClosedRange<Double>
  ) -> some View {
    LabeledContent(label) {
      HStack {
        Slider(value: value, in: range, step: 1)
        Text("\(Int(current)) pt")
          .monospacedDigit()
          .frame(width: 40, alignment: .trailing)
      }
    }
  }
}

private struct WorktreeSettingsTab: View {
  let model: AppModel

  var body: some View {
    let defaults = model.workspace.worktreeDefaults
    Form {
      Section {
        TextField("Worktree path:", text: field(\.worktreeDirectory))
        SettingsCaption(
          "Where each project's worktrees are created. Absolute, or relative to the repository. {project} is the repository folder name, ~ is home. Default ../{project}-worktrees."
        )
      }

      Section {
        TextField("Branch prefix:", text: field(\.branchPrefix), prompt: Text("none"))
        SettingsCaption(
          defaults.branchPrefix.isEmpty
            ? "Prepended to branch names typed in the new-worktree sheet."
            : "Typing tabs creates \(defaults.qualifiedBranch("tabs")).")
      }

      Section {
        SettingsCaption("Any project can override either value from its own settings.")
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
