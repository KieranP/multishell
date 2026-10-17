import MultishellGitKit

/// An opened submodule's own files and changes, marked against its own
/// repository. An uninitialised one has neither and lists as an empty folder.
struct SubmoduleReading: Equatable, Sendable {
  static let uninitialised = Self(tracked: .empty, status: nil)

  let tracked: TrackedFiles
  let status: WorktreeStatus?
}
