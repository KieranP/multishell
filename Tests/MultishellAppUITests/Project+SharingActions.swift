@testable import MultishellCore

extension Project {
  /// The project with a `.multishell.json` shipping three actions, not yet
  /// trusted, as the Actions page's tallest case lays out.
  @MainActor
  func sharingActions() -> Project {
    let shared = SharedProjectSettings(
      actions: [
        ProjectAction(name: "Start Server", command: "npm run dev -- --port $MULTISHELL_PORT"),
        ProjectAction(name: "Run Migrations", command: "bin/rails db:migrate"),
        ProjectAction(name: "Seed Database", command: "bin/rails db:seed"),
      ]
    )
    var sharing = self
    sharing.sharedSettingsSnapshot = SharedSettingsSnapshot(
      asWritten: shared,
      confined: shared,
      hasBeenRead: true,
    )
    return sharing
  }
}
