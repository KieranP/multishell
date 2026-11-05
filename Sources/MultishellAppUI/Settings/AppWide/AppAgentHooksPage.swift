import MultishellAppCore
import SwiftUI

/// All Projects > Agents > Agent hooks: a row per agent found, growing with each
/// agent installed, and the command line tool. None is recommended here.
struct AppAgentHooksPage: View {
  let model: AppModel

  var body: some View {
    SettingsForm {
      if !model.agentHooksRows.isEmpty {
        AgentHooksSection(model: model)
      }
      SettingsGroup(t("agents.command-line-tool")) {
        InfoLabeledContent(t("agents.helper-label"), info: t("agents.helper-info")) {
          Text(model.commandLineToolStatusText)
            .foregroundStyle(.secondary)
          if !model.isCommandLineToolInstalled {
            Button(t("agents.install-helper")) { model.installCommandLineTool() }
          }
        }
      }
    }
    .onAppear { model.refreshInstallState() }
  }
}
