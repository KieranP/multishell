/// How far the branch scans have got with a project's default branch, which
/// the settings row's Global column and caption both word.
enum DefaultBranchProgress: Equatable {
  case awaitingScan
  case scanned
  /// No git, or the folder gone: no scan will come, and an earlier one no longer holds.
  case unscannable
}
