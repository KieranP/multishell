import Foundation
import MultishellCore

/// What a project settings form shows for a setting the project does not
/// override: the value actually in force, and the sentence saying where it
/// comes from.
///
/// The global is not the only answer any more, since the repository's
/// `.multishell.json` may say what a worktree here opens and what order its
/// rows come in. A form that showed the global would tell the user the
/// opposite of what the app does, and turning the override on would seed it
/// with a value nobody was using.
public struct InheritedSetting<Value: Equatable & Sendable>: Equatable, Sendable {
  public let value: Value
  /// The repository's file supplies it, rather than the user's global.
  public let isFromRepository: Bool

  public init(value: Value, isFromRepository: Bool) {
    self.value = value
    self.isFromRepository = isFromRepository
  }

  /// The caption under the row while the override is off. `shown` is the
  /// value as the row itself writes it, so one sentence serves every kind
  /// of setting and none of them can word it differently.
  public func caption(_ shown: String) -> String {
    isFromRepository
      ? "Using the value in \(SharedProjectSettings.fileName): \(shown)."
      : "Using the global value: \(shown)."
  }
}

/// The original, and still the common case.
public typealias InheritedFlag = InheritedSetting<Bool>

extension InheritedSetting where Value == Bool {
  public var caption: String { caption(value ? "on" : "off") }
}

extension InheritedSetting where Value == WorktreeSortOrder {
  /// The label the picker gives it, so the caption and the row agree.
  public var caption: String { caption(value.displayName) }
}
