/// What arrives from outside the engine: reports about a session, which only
/// the program in it can make, and the command line's requests; agents.md.
@MainActor
public protocol MessageSource: AnyObject {
  var onReport: (@MainActor (SessionStateReport) -> Void)? { get set }
  /// Answers each request; `nil` gives none, which the helper reads as no answer.
  var onRequest: ControlRequestHandler?
  {
    get set
  }

  func start() throws
  func stop()
}
