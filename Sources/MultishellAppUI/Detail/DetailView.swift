import MultishellAppCore
import MultishellCore
import SwiftUI

struct DetailView: View {
  let model: AppModel

  @AppStorage(FilesPanelStorage.widthKey) private var filesPanelWidth = FilesPanelWidth.initial

  var body: some View {
    let theme = model.currentTheme
    VStack(spacing: 0) {
      switch model.detailContent {
      case .cover(.agentBoard):
        AgentBoardView(model: model, theme: theme)

      case .cover(.debugInfo):
        DebugInfoView(model: model, theme: theme)

      case .operation(let worktree, let operation):
        WorktreeHeader(model: model, worktree: worktree, theme: theme)
        WorktreeOperationView(
          operation: operation,
          theme: theme,
          metrics: model.metrics,
          cancel: { model.cancelStage(of: worktree) },
          dismiss: { model.dismissOperationFailure(of: worktree) },
        )

      case .tabGroups(let worktree):
        WorktreeHeader(model: model, worktree: worktree, theme: theme)
        besideFilesPanel(of: worktree, theme: theme) {
          WorktreeTabGroups(model: model, worktree: worktree, theme: theme)
        }

      case .noTabs(let worktree):
        WorktreeHeader(model: model, worktree: worktree, theme: theme)
        besideFilesPanel(of: worktree, theme: theme) { Spacer() }

      case .noSelection(let hasProjects):
        // Clears the title-bar band, like the header does.
        Color.clear.windowHeader()
        NoSelectionPlaceholder(hasProjects: hasProjects, theme: theme, metrics: model.metrics) {
          Task { await model.addProjectFromPicker() }
        }
      }
    }
    // The widest sidebar leaves less than the header needs. Clipped from the
    // leading side, so the actions menu is what stays in view.
    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
    .clipped()
    .background(theme.detail.background)
  }

  /// The worktree's tab area with the Files panel at its right while open,
  /// resized from its left edge as the sidebar is from its right.
  private func besideFilesPanel(
    of worktree: Worktree,
    theme: Theme,
    @ViewBuilder content: () -> some View,
  ) -> some View {
    let tabArea = content()
    return GeometryReader { area in
      let range = FilesPanelWidth.range(inDetailOfWidth: area.size.width)
      HStack(spacing: 0) {
        tabArea.frame(maxWidth: .infinity, maxHeight: .infinity)
        if model.isFilesPanelOnScreen {
          ResizeHandle(
            width: $filesPanelWidth,
            range: range,
            initial: FilesPanelWidth.initial,
            dragged: FilesPanelWidth.dragged,
            palette: theme.filesPanel,
          )
          FilesPanel(model: model, worktree: worktree, theme: theme)
            .frame(width: filesPanelWidth.clamped(to: range))
        }
      }
    }
  }
}
