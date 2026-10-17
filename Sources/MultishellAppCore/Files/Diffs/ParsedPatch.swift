/// What one file's `git diff -p` says, read into rows.
enum ParsedPatch: Equatable, Sendable {
  /// git reports a binary file, from its bytes or a `-diff` attribute.
  case binary
  /// Every line of the file, in context, with its changes.
  case lines([DiffLine])
  /// Headers and no hunk: only the file's mode changed.
  case modeOnly
  /// Nothing printed: the file is as `HEAD` has it, or untracked.
  case unchanged
}
