import Foundation
import MultishellCore

/// What a project settings form shows for a flag the project does not
/// override: the value actually in force, and the sentence saying where it
/// comes from.
///
/// The global is not the only answer any more, since the repository's
/// `.multishell.json` may say what a worktree here opens. A form that
/// showed the global would tell the user the opposite of what the app does,
/// and turning the override on would seed it with a value nobody was using.
public struct InheritedFlag: Equatable, Sendable {
  public let value: Bool
  /// The repository's file supplies it, rather than the user's global.
  public let isFromRepository: Bool

  public init(value: Bool, isFromRepository: Bool) {
    self.value = value
    self.isFromRepository = isFromRepository
  }

  /// The caption under the row while the override is off.
  public var caption: String {
    let state = value ? "on" : "off"
    return isFromRepository
      ? "Using the value in \(SharedProjectSettings.fileName): \(state)."
      : "Using the global value: \(state)."
  }
}
