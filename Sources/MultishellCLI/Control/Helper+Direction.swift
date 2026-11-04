import MultishellCore

extension Helper {
  /// `--next` or `--previous`, as an arrow is one or the other; `nil` for
  /// neither. Both is a usage error naming `command`.
  static func direction(
    in options: CommandOptions,
    command: String,
    topic: String,
  ) throws -> CycleDirection? {
    switch (options.has("next"), options.has("previous")) {
    case (true, false): .next
    case (false, true): .previous
    case (false, false): nil

    case (true, true):
      throw UsageError("\(command) takes --next or --previous, not both", topic: topic)
    }
  }
}
