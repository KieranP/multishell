import Foundation

/// One key `multishell config global` reads and writes, written through the
/// setter the Settings window calls, so what follows a change still does.
@MainActor
struct ControlSetting {
  let key: String
  /// JSON-ready: a Bool, a number, a String, or NSNull for none.
  let read: () -> Any
  /// `false` where the text is no value the key takes.
  let write: (String) -> Bool

  static func flag(
    _ key: String,
    _ read: @escaping () -> Bool,
    _ write: @escaping (Bool) -> Void,
  ) -> Self {
    Self(
      key: key,
      read: read,
      write: { text in
        guard let value = Bool(text) else { return false }
        write(value)
        return true
      },
    )
  }

  static func text(
    _ key: String,
    _ read: @escaping () -> String,
    accepts: @escaping (String) -> Bool = { _ in true },
    _ write: @escaping (String) -> Void,
  ) -> Self {
    Self(
      key: key,
      read: read,
      write: { text in
        guard accepts(text) else { return false }
        write(text)
        return true
      },
    )
  }

  /// Empty text is none, which reads back as null.
  static func optionalText(
    _ key: String,
    _ read: @escaping () -> String?,
    accepts: @escaping (String) -> Bool = { _ in true },
    _ write: @escaping (String?) -> Void,
  ) -> Self {
    Self(
      key: key,
      read: { read().map { $0 as Any } ?? NSNull() },
      write: { text in
        guard text.isEmpty || accepts(text) else { return false }
        write(text.isEmpty ? nil : text)
        return true
      },
    )
  }

  /// Refused outside `range` rather than clamped, so a write reads back as given.
  static func number<Value: LosslessStringConvertible & Comparable>(
    _ key: String,
    _ read: @escaping () -> Value,
    in range: ClosedRange<Value>,
    _ write: @escaping (Value) -> Void,
  ) -> Self {
    Self(
      key: key,
      read: read,
      write: { text in
        guard let value = Value(text), range.contains(value) else { return false }
        write(value)
        return true
      },
    )
  }

  static func choice<Value: RawRepresentable<String>>(
    _ key: String,
    _ read: @escaping () -> Value,
    _ write: @escaping (Value) -> Void,
  ) -> Self {
    choice(key, read, named: { $0.rawValue }, from: { Value(rawValue: $0) }, write)
  }

  /// One the command line names in the app's words, where the state file keeps
  /// those an earlier build wrote.
  static func choice<Value>(
    _ key: String,
    _ read: @escaping () -> Value,
    named name: @escaping (Value) -> String,
    from parse: @escaping (String) -> Value?,
    _ write: @escaping (Value) -> Void,
  ) -> Self {
    Self(
      key: key,
      read: { name(read()) },
      write: { text in
        guard let chosen = parse(text) else { return false }
        write(chosen)
        return true
      },
    )
  }
}
