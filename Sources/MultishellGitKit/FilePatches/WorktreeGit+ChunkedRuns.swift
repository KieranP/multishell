import MultishellCore

/// A read of many paths split into runs a command's worth long.
extension WorktreeGit {
  /// `run` once a chunk of `paths`, in turn; `nil` where any run fails.
  static func runs<Part>(
    over paths: [String],
    _ run: ([String]) async -> Part?,
  ) async -> [Part]? {
    var parts: [Part] = []
    for chunk in paths.chunked(into: pathsPerCommand) {
      guard let part = await run(chunk) else { return nil }
      parts.append(part)
    }
    return parts
  }
}
