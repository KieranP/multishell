/// The keys the user gave a project's actions, by action name. The user's
/// alone: the repository's file carries none, as keys are the app's.
public struct ActionShortcuts: Hashable, Sendable {
  private(set) var entries: [String: KeyCombination] = [:]

  public var isEmpty: Bool { entries.isEmpty }

  public func keys(for name: String) -> KeyCombination? {
    entries[name]
  }

  /// The action whose keys these are, if any.
  func name(holding keys: KeyCombination) -> String? {
    entries.first { $0.value == keys }?.key
  }

  /// Keys another action held move here, so no two actions share them.
  public mutating func set(_ keys: KeyCombination?, for name: String) {
    if let keys, let holder = self.name(holding: keys) { entries[holder] = nil }
    entries[name] = keys
  }

  /// A renamed action keeps its keys, unless the new name holds keys already:
  /// those are a `.multishell.json` action's, which the renamed one now stands in for.
  public mutating func rename(_ old: String, to new: String) {
    guard old != new, let keys = entries.removeValue(forKey: old), entries[new] == nil else {
      return
    }
    entries[new] = keys
  }
}
