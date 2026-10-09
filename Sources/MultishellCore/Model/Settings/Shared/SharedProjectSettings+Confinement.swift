import Foundation

extension SharedProjectSettings {
  /// The three fields that put paths on the reader's disk, held to the
  /// checkout; see settings.md. The digest is untouched, so a yes still holds.
  public func confined(to project: Project) -> SharedProjectSettings {
    var confined = self
    if let directory = worktreeDirectory,
      !RepositoryContainment.holds(
        directory: WorktreeSettings(worktreeDirectory: directory)
          .worktreeContainer(for: project),
        under: project.path,
      )
    {
      confined.worktreeDirectory = nil
    }
    confined.linkedPaths = RepositoryContainment.keepingContained(
      listedPaths: linkedPaths,
      under: project.path,
    )
    confined.copiedPaths = RepositoryContainment.keepingContained(
      listedPaths: copiedPaths,
      under: project.path,
    )
    return confined
  }
}
