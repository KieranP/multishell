/// For tests, and for a platform without a channel yet.
@MainActor
public final class NullStateSource: SessionStateSource {
  public var onReport: (@MainActor (SessionStateReport) -> Void)?
  public init() {}
  public func start() throws {}
  public func stop() {}
}
