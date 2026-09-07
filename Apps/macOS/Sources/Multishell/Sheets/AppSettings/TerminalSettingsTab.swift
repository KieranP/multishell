import MultishellAppCore
import MultishellCore
import SwiftUI

/// What a tab runs and when one starts. The font is under Appearance with
/// the rest of the look.
struct TerminalSettingsTab: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        InfoRow("Terminal engine:", info: engineInfo) {
          Picker(
            "Terminal engine:",
            selection: model.setting(\.terminalEngine, write: model.setTerminalEngine)
          ) {
            ForEach(TerminalEngine.allCases, id: \.self) { Text($0.displayName).tag($0) }
          }
        }
        DetectionPicker(
          label: "Default shell:",
          selection: model.setting(
            \.defaultShell, or: ShellCatalogue.loginShellID, write: model.setDefaultShell),
          options: model.shellDetection.options(selected:),
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
              text: model.setting(\.customShellPath, write: model.setCustomShellPath),
              prompt: Text("/opt/homebrew/bin/nu"))
          }
          if let problem = model.customShellPathProblem {
            SettingsCaption(problem)
          }
        }
        InfoToggle(
          "Open a terminal when a worktree is selected",
          info:
            "On, clicking a worktree with no tabs starts its first shell, or the agent where auto-start on tab open is on. Off, the worktree is shown empty and New Tab (⌘T) or the header's actions menu starts one. A worktree just created is the setting below's to decide. Any project can override this.",
          isOn: model.setting(\.opensTerminalOnSelect, write: model.setOpensTerminalOnSelect))
        InfoToggle(
          "Open a terminal when a worktree is created",
          info:
            "On, a worktree gets its first shell as soon as it is created, or once its post-create hook has finished, whatever selecting a worktree does. Off, the new worktree is shown empty. Any project can override this.",
          isOn: model.setting(\.opensTerminalOnCreate, write: model.setOpensTerminalOnCreate))
      }
    }
    .formStyle(.grouped)
  }

  private var engineInfo: String {
    model.workspace.terminalEngine == .swiftTerm
      ? "Used for every terminal opened from now on. Terminals already running keep the engine that started them. SwiftTerm has no shell integration and swallows the bell, so under it the state dots come from agent hooks alone."
      : "Used for every terminal opened from now on. Terminals already running keep the engine that started them."
  }
}
