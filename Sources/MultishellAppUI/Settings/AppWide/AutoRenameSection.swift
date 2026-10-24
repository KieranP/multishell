import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Agents' Auto Rename: which agent names a worktree, apart from
/// the one new tabs start, and the model and effort it is run at.
struct AutoRenameSection: View {
  let model: AppModel

  var body: some View {
    Section(t("agents.auto-rename")) {
      DetectionPicker(
        label: t("agents.rename-agent"),
        selection: model.settingBinding(\.renameAgentID, or: AppModel.renameUnsetID) { id in
          model.setRenameAgent(id)
        },
        options: { _ in model.renameAgentOptions },
        refreshing: model,
        info: t("agents.rename-agent-info"),
      )
      DetectionPicker(
        label: t("agents.rename-model"),
        selection: model.settingBinding(\.renameModel, or: AppModel.renameUnsetID) { modelID in
          model.setRenameModel(modelID)
        },
        options: { _ in model.renameModelOptions },
        info: t("agents.rename-model-info"),
        isEnabled: model.canChooseRenameModel,
      )
      DetectionPicker(
        label: t("agents.rename-effort"),
        selection: model.settingBinding(\.renameEffort, or: AppModel.renameUnsetID) { effort in
          model.setRenameEffort(effort)
        },
        options: { _ in model.renameEffortOptions },
        info: t("agents.rename-effort-info"),
        isEnabled: model.canChooseRenameEffort,
      )
    }
  }
}
