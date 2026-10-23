import Observation

@testable import MultishellAppCore
@testable import MultishellCore

/// Reads the panel as `FilesPanel.body` does and reads it again whenever what it read
/// changes, so a landing that leaves no dependency behind is never drawn.
@MainActor
final class FilesPanelRenderer {
  private let model: AppModel<FakeSurface>
  private let id: Worktree.ID
  private(set) var rows: [FileTreeRow] = []

  init(_ model: AppModel<FakeSurface>, showing id: Worktree.ID) {
    self.model = model
    self.id = id
    render()
  }

  private func render() {
    withObservationTracking {
      _ = model.filesPanelSummary(of: id)
      rows = model.fileTreeRows(of: id)
    } onChange: { [weak self] in
      Task { @MainActor in self?.render() }
    }
  }
}
