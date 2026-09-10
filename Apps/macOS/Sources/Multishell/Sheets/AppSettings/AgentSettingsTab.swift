import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Agents: the preferred agent, and the hooks that feed the
/// state dots, one row per agent this machine has.
///
/// What detection found and nothing else. No agent is named here, none is
/// recommended, and none is offered an installer: a machine with none
/// installed gets an empty picker, which says the same thing without
/// pointing anywhere.
struct AgentSettingsTab: View {
  let model: AppModel

  /// Which row's file is on show, at most one at a time.
  @State private var shownContents: String?

  var body: some View {
    Form {
      Section {
        DetectionPicker(
          label: "Preferred agent:",
          selection: model.setting(
            \.preferredAgentID, or: AgentCatalogue.noneID, write: model.setPreferredAgent),
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
              text: model.setting(\.customAgentCommand, write: model.setCustomAgentCommand),
              prompt: Text("my-agent --flag"))
          }
        }
        InfoToggle(
          "Auto-start on tab open",
          info:
            "New Tab (⌘T), and the first tab of a worktree you turn to, run the agent instead of a shell. New Shell Tab, in the File menu (⇧⌘T) and the worktree menu, and splits stay shells. A saved agent tab resumes its conversation on relaunch where the agent can.",
          isOn: model.setting(\.autoStartAgent, write: model.setAutoStartAgent)
        )
        .disabled(model.workspace.preferredAgentID == nil)
        InfoToggle(
          "Auto-start on worktree creation",
          info:
            "The tab a newly created worktree opens runs the agent instead of a shell, whatever tabs opened any other way do. Nothing opens at all unless Terminal > Open a terminal when a worktree is created is on. Any project can override this.",
          isOn: model.setting(\.autoStartAgentOnCreate, write: model.setAutoStartAgentOnCreate)
        )
        .disabled(model.workspace.preferredAgentID == nil)
      }

      if !model.agentHooksRows.isEmpty {
        hooksSection
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

  private var hooksSection: some View {
    Section("Agent hooks") {
      ForEach(model.agentHooksRows) { row in
        InfoRow("\(row.name):", info: row.info) {
          Text(row.isInstalled ? "Installed in \(row.path)" : "Not installed")
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.head)
          if row.isInstalled {
            Button("Remove") { model.removeAgentHooks(row.id) }
          } else {
            Button("Add") { model.installAgentHooks(row.id) }
          }
          Button(shownContents == row.id ? "Hide \(row.contentsName)" : "Show \(row.contentsName)")
          {
            shownContents = shownContents == row.id ? nil : row.id
          }
        }
        .controlSize(.small)
        if shownContents == row.id {
          contents(of: row)
        }
      }
    }
  }

  private func contents(of row: AgentHooksRow) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      ScrollView(.vertical) {
        Text(model.agentHooksSnippet(row.id))
          .font(.system(size: 10, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(height: 140)
      Button("Copy") { model.copyToClipboard(model.agentHooksSnippet(row.id)) }
        .controlSize(.small)
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
