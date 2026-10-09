import MultishellAppCore
import SwiftUI

/// The new-worktree sheet's agent rows: whether the first tab starts one, and
/// with the switch on, which agent and the task it starts on.
struct NewWorktreeAgentFields: View {
  let model: AppModel
  @Binding var draft: NewWorktreeDraft

  var body: some View {
    Section {
      Toggle(t("sheet.start-agent"), isOn: $draft.startsAgent)
      if draft.startsAgent {
        Picker(t("sheet.agent"), selection: pickedAgent) {
          ForEach(draft.offeredAgentIDs, id: \.self) { id in
            Text(model.agentDisplayName(id)).tag(id)
          }
        }
        TextField(
          t("sheet.task"), text: $draft.task, prompt: Text(t("sheet.task-prompt")),
          axis: .vertical
        )
        .lineLimit(3...8)
      }
    }
  }

  private var pickedAgent: Binding<String> {
    Binding(get: { draft.agentID }, set: { draft.pickAgent($0) })
  }
}
