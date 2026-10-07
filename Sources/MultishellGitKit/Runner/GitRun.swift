import Foundation
import MultishellProcess

/// One git process the app ran: what it was asked, where, and for how long.
public struct GitRun: Sendable, Equatable {
  /// The subcommand and its flags; see `GitCommandName`.
  public let command: String
  public let directory: URL
  public let duration: Duration
  /// git's own peak footprint and CPU time, its children left out; `nil`
  /// where unread.
  public let exitUsage: ExitUsage?
}
