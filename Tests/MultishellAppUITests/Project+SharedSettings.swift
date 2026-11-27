@testable import MultishellCore

extension Project {
  /// The tallest the hooks page's Create group gets: the trust section
  /// stands above it.
  @MainActor
  func askingForTrust() -> Project {
    sharing(SharedProjectSettings(preCreateHook: "make setup", postCreateHook: "npm ci"))
  }

  /// The project with a `.multishell.json` shipping three actions, not yet
  /// trusted, as the Actions page's tallest case lays out.
  @MainActor
  func sharingActions() -> Project {
    sharing(
      SharedProjectSettings(
        actions: [
          ProjectAction(name: "Start Server", command: "npm run dev -- --port $MULTISHELL_PORT"),
          ProjectAction(name: "Run Migrations", command: "bin/rails db:migrate"),
          ProjectAction(name: "Seed Database", command: "bin/rails db:seed"),
        ]
      )
    )
  }

  /// The project with `shared` read from its repository and not yet trusted.
  private func sharing(_ shared: SharedProjectSettings) -> Project {
    var project = self
    project.sharedSettingsSnapshot = SharedSettingsSnapshot(
      asWritten: shared,
      confined: shared,
      hasBeenRead: true,
    )
    return project
  }
}
