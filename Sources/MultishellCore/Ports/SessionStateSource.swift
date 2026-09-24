import Foundation

/// Reports about a session from outside the engine. Only the program in the
/// terminal can say it is waiting; see Docs/design/agents.md.
@MainActor
public protocol SessionStateSource: AnyObject {
  var onReport: (@MainActor (SessionStateReport) -> Void)? { get set }

  func start() throws
  func stop()
}
