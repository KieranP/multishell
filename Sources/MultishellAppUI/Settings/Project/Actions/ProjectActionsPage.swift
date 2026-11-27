import MultishellAppCore
import MultishellCore
import SwiftUI

/// The user's own actions, edited in place, and the repository's, read only
/// and grey until trusted; see Docs/design/actions.md.
struct ProjectActionsPage: View {
  let model: AppModel
  let project: Project

  @State private var draggedActionID: ProjectAction.ID?
  @State private var actionRowDrop: ActionRowDrop?

  var body: some View {
    let shared = project.sharedSettingsSnapshot.confined
    let sharedActions = shared?.actions ?? []
    SettingsForm {
      SharedSettingsHeader(model: model, project: project, lines: .actions)
      ownTable
      if !sharedActions.isEmpty { sharedTable(sharedActions) }
    }
    .onDisappear { model.endActionKeysRecording() }
  }

  private var ownTable: some View {
    let own = model.ownSettings(of: project).actions
    return VStack(alignment: .leading, spacing: 6) {
      ActionTable(title: t("actions.yours")) {
        // By index, a removal handed an edit to the next row; by name, a rename
        // rebuilt the row and Tab lost the command field.
        ForEach(Array(own.enumerated()), id: \.element.id) { index, action in
          OwnActionRow(
            model: model,
            project: project,
            action: action,
            index: index,
            dropDestination: actionRowDrop?.row == index ? dropDestination(in: own) : nil,
            draggedActionID: $draggedActionID,
            drop: $actionRowDrop,
          )
        }
      }
      HStack(spacing: 6) {
        Button(t("actions.add")) { model.addAction(to: project) }
        InfoButton(t("actions.info"))
      }
      .padding(.horizontal, UIMetrics.settingsRowSideInset)
    }
  }

  /// Where the row in the air lands at the line now showing.
  private func dropDestination(in own: [ProjectAction]) -> Int? {
    guard let actionRowDrop, let draggedActionID,
      let source = own.firstIndex(where: { $0.id == draggedActionID })
    else { return nil }
    return actionRowDrop.destination(movingFrom: source)
  }

  private func sharedTable(_ actions: [ProjectAction]) -> some View {
    let isTrusted = model.trustsSharedSettings(of: project)
    let textStyle = isTrusted ? AnyShapeStyle(.primary) : AnyShapeStyle(SettingsColors.faintText)
    return ActionTable(title: t("actions.from-file", SharedProjectSettings.fileName)) {
      ForEach(actions, id: \.name) { action in
        sharedRow(
          action,
          isStoodIn: model.ownActionStandsIn(forFileAction: action.name, in: project),
          showsKeys: model.fileRowShowsKeys(forFileAction: action.name, in: project),
          textStyle: textStyle,
        )
      }
    }
  }

  private func sharedRow(
    _ action: ProjectAction,
    isStoodIn: Bool,
    showsKeys: Bool,
    textStyle: AnyShapeStyle,
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      ActionColumns {
        Text(action.name).foregroundStyle(textStyle)
      } command: {
        Text(action.command)
          .font(.system(size: UIMetrics.settingsControlTextSize, design: .monospaced))
          .foregroundStyle(SettingsColors.secondaryText)
          .lineLimit(2)
          .truncationMode(.tail)
      } keys: {
        if showsKeys { ActionKeysCell(model: model, project: project, name: action.name) }
      }
      if isStoodIn {
        Text(t("actions.replaced-by-yours"))
          .font(.system(size: UIMetrics.settingsSmallTextSize))
          .foregroundStyle(SettingsColors.secondaryText)
      }
    }
  }
}
