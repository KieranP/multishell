import MultishellCore

extension Helper {
  /// Where `--before ID` or `--after ID` puts a moved thing, and the ID; `nil`
  /// where neither is given. Both is a usage error naming `usage`.
  static func placement(
    in options: CommandOptions,
    usage: String,
    topic: String,
  ) throws -> (placement: WorkspaceTab.Placement, anchor: String)? {
    switch (options["before"], options["after"]) {
    case (let anchor?, nil): (.before, anchor)
    case (nil, let anchor?): (.after, anchor)
    case (nil, nil): nil
    case (.some, .some): throw UsageError(usage, topic: topic)
    }
  }
}
