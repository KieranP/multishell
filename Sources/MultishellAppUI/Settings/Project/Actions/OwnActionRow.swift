import MultishellAppCore
import MultishellCore
import SwiftUI

/// One of the user's own actions on the Actions page: its handle, name,
/// command and keys, and its place as a target for another row dragged there.
struct OwnActionRow: View {
  let model: AppModel
  let project: Project
  let action: ProjectAction
  let index: Int
  /// Where a row dropped on the line now showing would end, `nil` for none.
  let dropDestination: Int?
  @Binding var draggedActionID: ProjectAction.ID?
  @Binding var drop: ActionRowDrop?

  var body: some View {
    ActionColumns {
      HStack(spacing: 6) {
        dragHandle
        ActionNameField(model: model, project: project, name: action.name, index: index)
      }
    } command: {
      TextField(
        t("actions.command"),
        text: Binding(
          get: { action.command },
          set: { model.setActionCommand($0, at: index, in: project) },
        ),
      )
      .labelsHidden()
      .font(.system(size: UIMetrics.settingsControlTextSize, design: .monospaced))
    } keys: {
      if action.hasName {
        ActionKeysCell(model: model, project: project, name: action.name)
      }
      Spacer(minLength: 0)
      SettingsSymbolButton(symbol: "minus.circle", help: t("actions.remove-help", action.name)) {
        model.removeAction(at: index, from: project)
      }
    }
    .opacity(draggedActionID == action.id ? 0.4 : 1)
    .modifier(
      ActionRowDropTarget(
        row: index,
        showsLine: dropDestination != nil,
        drop: $drop,
        perform: moveDraggedRow,
      )
    )
    .accessibilityAction(named: t("actions.move-up")) {
      model.moveAction(action.id, to: index - 1, in: project)
    }
    .accessibilityAction(named: t("actions.move-down")) {
      model.moveAction(action.id, to: index + 1, in: project)
    }
  }

  // VoiceOver moves the row by its Move Up and Move Down actions instead.
  private var dragHandle: some View {
    Image(systemName: "line.3.horizontal")
      .foregroundStyle(SettingsColors.secondaryText)
      .contentShape(.rect)
      .help(t("actions.drag-help"))
      .accessibilityHidden(true)
      .inAppDragSource(
        begin: {
          draggedActionID = action.id
          return ActionRowTransfer.itemProvider()
        },
        preview: { preview },
        onEnded: endDrag,
        onSourceLeft: { _ in endDrag() },
      )
  }

  private var preview: some View {
    Text(action.hasName ? action.name : t("actions.name"))
      .font(.system(size: UIMetrics.settingsControlTextSize))
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(.regularMaterial, in: .rect(cornerRadius: 6))
  }

  private func moveDraggedRow(_ drop: ActionRowDrop) -> Bool {
    defer { endDrag() }
    guard let draggedActionID, let dropDestination else { return false }
    withAnimation(.easeOut(duration: 0.14)) {
      model.moveAction(draggedActionID, to: dropDestination, in: project)
    }
    return true
  }

  private func endDrag() {
    draggedActionID = nil
    drop = nil
  }
}
