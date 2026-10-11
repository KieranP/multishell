/// For tests, and for a platform without a channel yet.
@MainActor
public final class NullMessageSource: MessageSource {
  public var onReport: (@MainActor (SessionStateReport) -> Void)?
  public var onRequest: ControlRequestHandler?
  public init() {}
  public func start() throws {}
  public func stop() {}
}
