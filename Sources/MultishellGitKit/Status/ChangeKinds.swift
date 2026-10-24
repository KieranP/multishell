/// Each changed path's kind, a path listed twice `combined`. Derived from the
/// change list beside it, so equal wherever that list is; kept inside GitKit.
struct ChangeKinds: Hashable, Sendable {
  private let kinds: [String: StatusChange.Kind]

  init(_ changes: [StatusChange]) {
    kinds = Dictionary(changes.map { ($0.path, $0.kind) }) { $0.combined(with: $1) }
  }

  /// Compared and hashed through the list it came from, never a second time.
  static func == (_: Self, _: Self) -> Bool { true }

  func hash(into _: inout Hasher) {}

  subscript(path: String) -> StatusChange.Kind? { kinds[path] }
}
