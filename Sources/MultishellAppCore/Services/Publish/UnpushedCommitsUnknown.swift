/// Create Pull Request where git could not count the commits the remote lacks.
struct UnpushedCommitsUnknown: Error {
  let branch: String
}
