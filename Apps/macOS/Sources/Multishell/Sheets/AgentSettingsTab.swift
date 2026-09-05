import MultishellCore
import SwiftUI

/// Settings > Agent: the preferred agent, and the Claude Code hooks that
/// feed the state dots, shown only when Claude Code is on the login shell's
/// PATH. Without it, the way to get it.
struct AgentSettingsTab: View {
  let model: AppModel

  @State private var showsSnippet = false

  var body: some View {
    Form {
      Section {
        AgentPicker(
          label: "Preferred agent:",
          selection: Binding(
            get: { model.workspace.preferredAgentID ?? AgentCatalogue.noneID },
            set: { model.setPreferredAgent($0) }),
          detection: model.agentDetection,
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info: environmentCaption
        )
        if model.workspace.preferredAgentID == AgentCatalogue.customID {
          TextField(
            "Command:",
            text: Binding(
              get: { model.workspace.customAgentCommand },
              set: { model.setCustomAgentCommand($0) }),
            prompt: Text("my-agent --flag"))
        }
        Toggle(
          "Start it in new tabs",
          isOn: Binding(
            get: { model.workspace.autoStartAgent }, set: { model.setAutoStartAgent($0) })
        )
        .disabled(model.workspace.preferredAgentID == nil)
        SettingsCaption(
          "New Tab (⌘T) and a worktree's first tab run the agent instead of a shell; New Shell Tab (⇧⌘T) still opens a shell, and splits stay shells. A saved agent tab resumes its conversation on relaunch where the agent can."
        )
      }

      if model.agentDetection.isClaudeCodeInstalled {
        claudeCodeSection
      } else {
        Section("Claude Code") {
          LabeledContent("Claude Code:") {
            Text("Not found on the login shell's PATH.").foregroundStyle(.secondary)
          }
          HStack {
            Button("Install…") { NSWorkspace.shared.open(AppModel.claudeCodeSetupURL) }
            Button("Copy Install Command") { copy(AppModel.claudeCodeInstallCommand) }
          }
          .controlSize(.small)
          SettingsCaption(
            "Opens the setup guide. The native installer is \(AppModel.claudeCodeInstallCommand); run Refresh above once it is done."
          )
        }
      }

      Section("Command line tool") {
        LabeledContent("multishell:") {
          HStack {
            Text(model.commandLineToolInstalled ? "Installed in /usr/local/bin" : "Not installed")
              .foregroundStyle(.secondary)
            if !model.commandLineToolInstalled {
              Button("Install Command Line Tool…") { model.installCommandLineTool() }
                .controlSize(.small)
            }
          }
        }
        SettingsCaption(
          "For your own hooks: `multishell state running|attention|done|error|idle` from any terminal in this app marks its tab. Asks for an administrator password."
        )
      }
    }
    .formStyle(.grouped)
    .onAppear { model.refreshAgentStatus() }
  }

  private var claudeCodeSection: some View {
    Section("Claude Code") {
      LabeledContent("Claude Code:") {
        Text(model.agentDetection.found[AgentCatalogue.claudeID]?.path ?? "")
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.head)
      }
      LabeledContent("Hooks:") {
        HStack {
          Text(model.claudeHooksInstalled ? "Installed" : "Not installed")
            .foregroundStyle(.secondary)
          if model.claudeHooksInstalled {
            Button("Remove") { model.removeClaudeHooks() }
          } else {
            Button("Add to ~/.claude/settings.json") { model.installClaudeHooks() }
          }
          Button(showsSnippet ? "Hide JSON" : "Show JSON") { showsSnippet.toggle() }
        }
        .controlSize(.small)
      }
      if showsSnippet {
        VStack(alignment: .leading, spacing: 6) {
          ScrollView(.vertical) {
            Text(model.claudeHooksSnippet)
              .font(.system(size: 10, design: .monospaced))
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .frame(height: 140)
          Button("Copy") { copy(model.claudeHooksSnippet) }.controlSize(.small)
        }
      }
      SettingsCaption(
        "Claude reports Working, Waiting for input and Done through its hooks, and the tab bar and sidebar colour the dot. Other hooks in the file are left as they are; the first write keeps a copy beside it."
      )
    }
  }

  private var environmentCaption: String {
    switch model.loginEnvironment?.source {
    case nil:
      return "Asking your login shell for its PATH…"
    case .loginShell(let shell):
      return
        "Agents are looked up on the PATH of \(shell.path) as an interactive login shell, the same one your terminals get. Refresh after installing one."
    case .processFallback(let reason):
      return
        "Your login shell did not answer (\(reason)), so agents are looked up on the app's own PATH. Refresh to try again."
    }
  }

  private func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }
}

/// The dropdown both settings windows use: None, installed agents, the
/// stored value marked when it is not installed, Custom, and a Refresh.
struct AgentPicker: View {
  let label: String
  @Binding var selection: String
  let detection: AgentDetection
  let refresh: () -> Void
  /// Where the lookup happened, behind an (i) rather than a caption under
  /// the row. A click opens a popover; a tooltip alone is easy to miss and
  /// answers no click.
  var info: String? = nil

  @State private var showsInfo = false

  var body: some View {
    LabeledContent(label) {
      HStack {
        Picker(label, selection: $selection) {
          ForEach(detection.options(selected: selection)) { option in
            Text(option.label).tag(option.id)
          }
        }
        .labelsHidden()
        Button("Refresh", action: refresh).controlSize(.small)
        if let info {
          Button {
            showsInfo.toggle()
          } label: {
            Image(systemName: "info.circle")
              .foregroundStyle(.secondary)
              .frame(width: 20, height: 20)
              .contentShape(.rect)
          }
          .buttonStyle(.plain)
          .help(info)
          .popover(isPresented: $showsInfo, arrowEdge: .bottom) {
            Text(info)
              .font(.system(size: 12))
              .fixedSize(horizontal: false, vertical: true)
              .frame(width: 320, alignment: .leading)
              .padding()
          }
        }
      }
    }
  }
}
