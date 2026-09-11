import Foundation

/// Reports about a session from outside the engine. Only the program in the
/// terminal can say it is waiting; see docs/design/agents.md.
@MainActor
public protocol SessionStateSource: AnyObject {
  var onReport: (@MainActor (SessionStateReport) -> Void)? { get set }

  func start() throws
  func stop()
}

/// For tests, and for a platform without a channel yet.
@MainActor
public final class NullStateSource: SessionStateSource {
  public var onReport: (@MainActor (SessionStateReport) -> Void)?
  public init() {}
  public func start() throws {}
  public func stop() {}
}
