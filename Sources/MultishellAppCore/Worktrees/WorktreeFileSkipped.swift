/// A user's own list entries that name somewhere other than the repository,
/// said once the rest are placed and the hook has been let run.
struct WorktreeFileSkipped: Error {
  let entries: [String]
}
