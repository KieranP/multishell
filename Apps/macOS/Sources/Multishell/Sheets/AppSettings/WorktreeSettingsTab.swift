import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Worktrees: where new worktrees go, how their branches are
/// named, and what a removal asks. Any project can override these.
struct WorktreeSettingsTab: View {
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
        InfoRow(
          "Hook timeout:",
          info:
            "How long a project hook may run before it is stopped and reported, in seconds. A hook that hangs would otherwise hold its worktree until relaunch. Stop Hook on the pane ends one sooner; 0 is no limit."
        ) {
          TextField(
            "Hook timeout:",
            value: model.setting(\.hookTimeoutSeconds, write: model.setHookTimeoutSeconds),
            format: .number
          )
          .frame(width: 60)
          .multilineTextAlignment(.trailing)
          Text("seconds")
        }
      }

      Section {
        InfoToggle(
          "Ask before removing a worktree",
          info:
            "The directory goes to the Trash and git prunes it. The confirmation also counts uncommitted changes and open terminals in that worktree. Off is for people who remove worktrees all day; a removal then still asks about the branch unless the toggle below settles it.",
          isOn: model.setting(
            \.confirmsWorktreeRemoval, write: model.setConfirmsWorktreeRemoval))
        InfoToggle(
          "Always delete the branch with its worktree",
          info:
            "Runs git branch -d after git worktree remove, once the post-delete hook has run. Off, removing a worktree asks whether the branch goes too. A branch with commits nothing else has is refused and offered again with the forced form.",
          isOn: model.setting(
            \.deletesBranchWithWorktree, write: model.setDeletesBranchWithWorktree))
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
