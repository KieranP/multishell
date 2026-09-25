import MultishellProcess

/// Raised when a hook fails. A pre hook's failure means the operation was
/// never asked for; a post hook's means it has already succeeded.
public struct HookFailure: Error, CustomStringConvertible {
  public let stage: HookStage
  public let underlying: any Error

  public var description: String {
    "\(stage.rawValue) hook failed: \(underlying)"
  }

  /// Why the hook did not finish on its own, when it did not: the timeout,
  /// or the user's stop.
  public var stop: ProcessStop? {
    (underlying as? ProcessFailure)?.stop
  }
}
