/// `--name value` pairs and bare `--flag`s after the subcommand. Anything
/// else is a usage error, so a typo in a hook line is caught rather than ignored.
struct CommandOptions {
  private let values: [String: String]
  private let presentFlags: Set<String>
  private let topic: String?

  init(
    _ arguments: ArraySlice<String>,
    valued: Set<String>,
    flags: Set<String> = [],
    topic: String? = nil,
  ) throws {
    var values: [String: String] = [:]
    var presentFlags: Set<String> = []
    var rest = arguments
    while let argument = rest.popFirst() {
      let name = String(argument.dropFirst(2))
      guard argument.hasPrefix("--") else {
        throw UsageError("unexpected argument \(argument)", topic: topic)
      }
      if flags.contains(name) {
        presentFlags.insert(name)
        continue
      }
      guard valued.contains(name), let value = rest.popFirst() else {
        throw UsageError("unexpected argument \(argument)", topic: topic)
      }
      values[name] = value
    }
    self.values = values
    self.presentFlags = presentFlags
    self.topic = topic
  }

  func has(_ flag: String) -> Bool { presentFlags.contains(flag) }

  /// `nil` where the option is not given; a value that is no number is a usage error.
  func int32(_ name: String) throws -> Int32? { try number(name, Int32.init) }

  func double(_ name: String) throws -> Double? { try number(name, Double.init) }

  func count(_ name: String) throws -> Int? {
    guard let count = try number(name, Int.init) else { return nil }
    guard count > 0 else { throw UsageError("--\(name) takes a count above zero", topic: topic) }
    return count
  }

  /// Whole or fractional seconds up to a day.
  func seconds(_ name: String) throws -> Duration? {
    guard let seconds = try double(name) else { return nil }
    guard seconds > 0, seconds <= 86_400 else {
      throw UsageError("--\(name) takes seconds above zero, a day at most", topic: topic)
    }
    return .seconds(seconds)
  }

  private func number<Number>(_ name: String, _ read: (String) -> Number?) throws -> Number? {
    guard let value = values[name] else { return nil }
    guard let number = read(value) else {
      throw UsageError("--\(name) takes a number, not \(value)", topic: topic)
    }
    return number
  }

  /// `nil` unless the value spells the one answer a hook sends, so a report
  /// leaves the field out rather than sending the default.
  func onlyIfTrue(_ name: String) -> Bool? { values[name] == "true" ? true : nil }

  func onlyIfFalse(_ name: String) -> Bool? { values[name] == "false" ? false : nil }

  subscript(name: String) -> String? { values[name] }
}
