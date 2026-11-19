/// The commands whose keys the user changed, and what to. Only changes are
/// kept, so a default a later build changes reaches every command left alone.
public struct ShortcutOverrides: Hashable, Sendable {
  private var entries: [ShortcutCommand: ShortcutOverride] = [:]

  public var isEmpty: Bool { entries.isEmpty }

  public init() {}

  /// The keys in force. A default another command's override now holds, as a
  /// later build's new default can be, leaves this command none.
  public func keys(for command: ShortcutCommand) -> KeyCombination? {
    if command.isFixed { return command.defaultCombination }
    switch entries[command] {
    case .keys(let keys): return keys
    case .noKeys: return nil

    case nil:
      let isTaken = entries.values.contains(.keys(command.defaultCombination))
      return isTaken ? nil : command.defaultCombination
    }
  }

  /// The command whose keys these are now, if any.
  public func command(holding keys: KeyCombination) -> ShortcutCommand? {
    ShortcutCommand.allCases.first { self.keys(for: $0) == keys }
  }

  /// `nil`, or the default itself, puts the command back on its default.
  public mutating func set(_ override: ShortcutOverride?, for command: ShortcutCommand) {
    guard !command.isFixed, override != .keys(command.defaultCombination) else {
      entries[command] = nil
      return
    }
    entries[command] = override
  }

  public subscript(command: ShortcutCommand) -> ShortcutOverride? {
    entries[command]
  }
}
