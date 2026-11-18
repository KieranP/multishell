import MultishellGitKit

/// A worktree's changes as git listed them and in the Changes list's order, so a
/// status landing that lists the same is not sorted again.
struct AllChangesListCacheEntry {
  let changes: [StatusChange]
  let list: [AllChangesFileChange]
}
