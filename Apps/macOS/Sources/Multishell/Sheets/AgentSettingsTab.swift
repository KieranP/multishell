import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Agents: the preferred agent, and the Claude Code hooks that
/// feed the state dots, shown only when Claude Code is on the login shell's
/// PATH. Without it, the way to get it.
struct AgentSettingsTab: View {
  let model: AppModel

  @State private var showsSnippet = false

  var body: some View {
    Form {
      Section {
        DetectionPicker(
          label: "Preferred agent:",
          selection: Binding(
            get: { model.workspace.preferredAgentID ?? AgentCatalogue.noneID },
            set: { model.setPreferredAgent($0) }),
          options: model.agentDetection.options(selected:),
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info: environmentCaption
        )
        if model.workspace.preferredAgentID == AgentCatalogue.customID {
          InfoRow(
            "Command:",
            info: "Run as typed through your login shell when an agent tab opens."
          ) {
            TextField(
              "Command:",
              text: Binding(
                get: { model.workspace.customAgentCommand },
                set: { model.setCustomAgentCommand($0) }),
              prompt: Text("my-agent --flag"))
          }
        }
        InfoToggle(
          "Start it in new tabs",
          info:
            "New Tab (⌘T) and a worktree's first tab run the agent instead of a shell. New Shell Tab, in the File menu (⇧⌘T) and the worktree menu, and splits stay shells. A saved agent tab resumes its conversation on relaunch where the agent can.",
          isOn: Binding(
            get: { model.workspace.autoStartAgent }, set: { model.setAutoStartAgent($0) })
        )
        .disabled(model.workspace.preferredAgentID == nil)
      }

      if model.agentDetection.isClaudeCodeInstalled {
        claudeCodeSection
      } else {
        Section("Claude Code") {
          InfoRow(
            "Claude Code:",
            info:
              "Opens the setup guide. The native installer is \(ClaudeCodeInstall.installerCommand); run Refresh above once it is done."
          ) {
            Text("Not found on the login shell's PATH.").foregroundStyle(.secondary)
            Button("Install…") { NSWorkspace.shared.open(ClaudeCodeInstall.setupGuideURL) }
              .controlSize(.small)
            Button("Copy Install Command") {
              model.copyToClipboard(ClaudeCodeInstall.installerCommand)
            }
            .controlSize(.small)
          }
        }
      }

      Section("Command line tool") {
        InfoRow(
          "multishell:",
          info:
            "For your own hooks: `multishell state running|attention|done|error|idle` from any terminal in this app marks its tab. Asks for an administrator password."
        ) {
          Text(model.commandLineToolInstalled ? "Installed in /usr/local/bin" : "Not installed")
            .foregroundStyle(.secondary)
          if !model.commandLineToolInstalled {
            Button("Install Command Line Tool…") { model.installCommandLineTool() }
              .controlSize(.small)
          }
        }
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
      InfoRow(
        "Hooks:",
        info:
          "Claude reports Working, Waiting for input and Done through its hooks, and the tab bar and sidebar colour the dot. Other hooks in the file are left as they are; the first write keeps a copy beside it."
      ) {
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
      if showsSnippet {
        VStack(alignment: .leading, spacing: 6) {
          ScrollView(.vertical) {
            Text(model.claudeHooksSnippet)
              .font(.system(size: 10, design: .monospaced))
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .frame(height: 140)
          Button("Copy") { model.copyToClipboard(model.claudeHooksSnippet) }.controlSize(.small)
        }
      }
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
}
