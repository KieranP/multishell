/// `--name value` pairs and bare `--flag`s after the subcommand. Anything
/// else is a usage error, so a typo in a hook line is caught rather than ignored.
struct CommandOptions {
  private let values: [String: String]
  private let setFlags: Set<String>

  /// `names` limits the pairs accepted; nil takes any.
  init(
    _ arguments: ArraySlice<String>, names: Set<String>? = nil, flags: Set<String> = []
  ) throws {
    var values: [String: String] = [:]
    var setFlags: Set<String> = []
    var rest = arguments
    while let argument = rest.popFirst() {
      let name = String(argument.dropFirst(2))
      guard argument.hasPrefix("--") else { throw UsageError("unexpected argument \(argument)") }
      if flags.contains(name) {
        setFlags.insert(name)
        continue
      }
      guard names?.contains(name) ?? true, let value = rest.popFirst() else {
        throw UsageError("unexpected argument \(argument)")
      }
      values[name] = value
    }
    self.values = values
    self.setFlags = setFlags
  }

  subscript(name: String) -> String? { values[name] }

  func has(_ flag: String) -> Bool { setFlags.contains(flag) }

  func int32(_ name: String) -> Int32? { values[name].flatMap { Int32($0) } }

  func double(_ name: String) -> Double? { values[name].flatMap { Double($0) } }
}
