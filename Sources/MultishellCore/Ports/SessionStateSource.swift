import Foundation

/// Reports about a session from outside the engine: an agent's hooks, a test
/// runner, a build, through whatever channel the platform provides.
///
/// The engine can say a bell rang or a command finished; only the program in
/// the terminal can say it is waiting for an answer. The GUI owns the channel
/// (a Unix socket on the Mac) and hands each parsed report to the core's
/// owner of runtime state.
@MainActor
public protocol SessionStateSource: AnyObject {
  var onReport: (@MainActor (SessionStateReport) -> Void)? { get set }

  func start() throws
  func stop()
}
