import Foundation

/// What a report keeps of each field, since any process of the user's can
/// write to the channel.
extension SessionStateReport {
  /// More than a notification banner shows, and far inside what the channel
  /// carries.
  static let maximumMessageLength = 500
  /// A week. Longer than any command the board is asked to time, and short
  /// of what `Int(_:)` cannot hold.
  private static let maximumDuration: Double = 7 * 24 * 60 * 60

  /// The first word without its path. The reader's rule, not the hook's: any
  /// process of the user's can write a line.
  static func commandWord(_ command: String?) -> String? {
    guard let word = command?.split(whereSeparator: \.isWhitespace).first,
      let name = word.split(separator: "/").last
    else { return nil }
    return boundedIdentifier(String(name))
  }

  /// macOS's PATH_MAX; a longer one is no directory a worktree could be.
  private static let maximumPathLength = 1024

  static func boundedPath(_ path: String?) -> String? {
    guard let path, path.utf8.count <= maximumPathLength else { return nil }
    return path
  }

  /// A duration outside what a command could have taken is a writer's
  /// number rather than a clock's, and is dropped as the message is capped.
  static func boundedDuration(_ duration: Double?) -> Double? {
    guard let duration, duration.isFinite, duration >= 0, duration <= maximumDuration
    else { return nil }
    return duration
  }

  /// Longer than any agent's id, and dropped rather than cut: a cut one
  /// would name a different worker.
  static let maximumIdentifierLength = 128

  /// The places a model's roster holds and the shells a report names, or an agent
  /// never ending its workers or a Stop naming thousands grows it for good.
  public static let rosterCapacity = 64

  /// A roster's places and the ids its overflow place folds, so a Stop can
  /// list all it holds; a list this long may have been cut, and prunes nothing.
  public static let maximumWorkersOut = 1024

  static func boundedIdentifier(_ id: String?) -> String? {
    guard let id, !id.isEmpty, id.count <= maximumIdentifierLength else { return nil }
    return id
  }

  /// Named ones only: an id past the limit decodes as unnamed, which is no
  /// worker a list can name.
  static func boundedWorkers(_ workers: [SubagentReport]?) -> [SubagentReport]? {
    workers.map {
      Array($0.filter { $0.id != SubagentReport.anonymousID }.prefix(maximumWorkersOut))
    }
  }

  static func boundedShells(_ pids: [Int32]?) -> [Int32]? {
    pids.map { Array($0.prefix(rosterCapacity)) }
  }

  static func truncatedMessage(_ message: String?) -> String? {
    message?.truncated(to: maximumMessageLength)
  }
}
